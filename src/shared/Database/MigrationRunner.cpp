/*
 * Copyright (C) 2005-2011 MaNGOS <http://getmangos.com/>
 * Copyright (C) 2009-2011 MaNGOSZero <https://github.com/mangos/zero>
 * Copyright (C) 2011-2016 Nostalrius <https://nostalrius.org>
 * Copyright (C) 2016-2017 Elysium Project <https://github.com/elysium-project>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "DatabaseEnv.h"
#include "Database/MysqlScript.h"
#include "Log.h"
#include "Config/Config.h"

#include <algorithm>
#include <cstring>
#include <fstream>
#include <set>
#include <vector>

#if defined(WIN32)
#include <windows.h>
#else
#include <limits.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

#if defined(__APPLE__)
#include <mach-o/dyld.h>
#endif

namespace
{
bool IsMigrationId(std::string const& id)
{
    if (id.empty() || id.size() > 32)
        return false;

    for (char c : id)
        if (c < '0' || c > '9')
            return false;

    return true;
}

bool IsMigrationSuffix(char const* suffix)
{
    return suffix &&
        (std::strcmp(suffix, "world") == 0 ||
         std::strcmp(suffix, "characters") == 0 ||
         std::strcmp(suffix, "logon") == 0 ||
         std::strcmp(suffix, "logs") == 0);
}

std::string NormalizeDir(std::string path)
{
    for (char& c : path)
        if (c == '\\')
            c = '/';

    while (path.size() > 1 && path.back() == '/')
        path.pop_back();

    return path;
}

std::string JoinPath(std::string dir, std::string const& leaf)
{
    if (dir.empty())
        return leaf;

    char const last = dir.back();
    if (last != '/' && last != '\\')
        dir.push_back('/');
    dir += leaf;
    return dir;
}

std::string ParentPath(std::string path)
{
    path = NormalizeDir(path);
    size_t const pos = path.find_last_of('/');
    if (pos == std::string::npos)
        return std::string();

    // Keep a Windows drive root ("C:") and a Unix root ("/") intact.
    if (pos == 0)
        return "/";
    if (pos == 2 && path[1] == ':')
        return path.substr(0, pos);

    return path.substr(0, pos);
}

bool FileExists(std::string const& path)
{
#if defined(WIN32)
    DWORD const attr = GetFileAttributesA(path.c_str());
    return attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY) == 0;
#else
    struct stat st;
    return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
#endif
}

std::string CurrentWorkingDirectory()
{
#if defined(WIN32)
    char buffer[32768];
    DWORD const len = GetCurrentDirectoryA(static_cast<DWORD>(sizeof(buffer)), buffer);
    if (len == 0 || len >= sizeof(buffer))
        return std::string();
    return std::string(buffer, len);
#else
    char buffer[PATH_MAX];
    if (!getcwd(buffer, sizeof(buffer)))
        return std::string();
    return buffer;
#endif
}

std::string ExecutablePath()
{
#if defined(WIN32)
    char buffer[32768];
    DWORD const len = GetModuleFileNameA(nullptr, buffer, static_cast<DWORD>(sizeof(buffer)));
    if (len == 0 || len >= sizeof(buffer))
        return std::string();
    return std::string(buffer, len);
#elif defined(__APPLE__)
    char buffer[PATH_MAX];
    uint32_t size = sizeof(buffer);
    if (_NSGetExecutablePath(buffer, &size) != 0)
        return std::string();
    char resolved[PATH_MAX];
    if (realpath(buffer, resolved))
        return resolved;
    return buffer;
#else
    char buffer[PATH_MAX];
    ssize_t const len = readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
    if (len <= 0)
        return std::string();
    buffer[len] = '\0';
    return buffer;
#endif
}

void AddDir(std::vector<std::string>& dirs, std::set<std::string>& seen, std::string path)
{
    path = NormalizeDir(std::move(path));
    if (path.empty() || !seen.insert(path).second)
        return;
    dirs.push_back(std::move(path));
}

void AddWalk(std::vector<std::string>& dirs, std::set<std::string>& seen, std::string start)
{
    for (int i = 0; i < 12 && !start.empty(); ++i)
    {
        AddDir(dirs, seen, JoinPath(start, "sql/migrations"));
        std::string parent = ParentPath(start);
        if (parent == start)
            break;
        start = std::move(parent);
    }
}

std::vector<std::string> MigrationSearchDirs()
{
    std::vector<std::string> dirs;
    std::set<std::string> seen;

    std::string const configured = sConfig.GetStringDefault("Database.MigrationsDir", "");
    if (!configured.empty())
    {
        AddDir(dirs, seen, configured);
        AddDir(dirs, seen, JoinPath(configured, "sql/migrations"));
    }

#ifdef MANGOS_SOURCE_DIR
    AddDir(dirs, seen, JoinPath(MANGOS_SOURCE_DIR, "sql/migrations"));
#endif

    std::string const configFile = sConfig.GetFilename();
    if (!configFile.empty())
        AddWalk(dirs, seen, ParentPath(configFile));

    std::string const executable = ExecutablePath();
    if (!executable.empty())
    {
        // A release layout may place the scripts beside the executable.
        AddDir(dirs, seen, ParentPath(executable));
        AddWalk(dirs, seen, ParentPath(executable));
    }

    AddWalk(dirs, seen, CurrentWorkingDirectory());
    return dirs;
}

std::string FindMigrationFile(std::vector<std::string> const& dirs, std::string const& filename, std::string& usedDir)
{
    for (std::string const& dir : dirs)
    {
        std::string const path = JoinPath(dir, filename);
        if (FileExists(path))
        {
            usedDir = dir;
            return path;
        }
    }
    return std::string();
}

bool ReadFile(std::string const& path, std::string& out, std::string& error)
{
    std::ifstream in(path.c_str(), std::ios::in | std::ios::binary);
    if (!in)
    {
        error = "Could not open " + path;
        return false;
    }

    in.seekg(0, std::ios::end);
    std::streamoff const size = in.tellg();
    if (size < 0)
    {
        error = "Could not read " + path;
        return false;
    }

    in.seekg(0, std::ios::beg);
    out.resize(static_cast<size_t>(size));
    if (size > 0 && !in.read(&out[0], size))
    {
        error = "Could not read " + path;
        return false;
    }

    return true;
}

std::string SqlSnippet(std::string const& sql)
{
    std::string snippet = sql.substr(0, 180);
    for (char& c : snippet)
        if (c == '\n' || c == '\r' || c == '\t')
            c = ' ';
    if (sql.size() > snippet.size())
        snippet += "...";
    return snippet;
}
}

bool Database::ApplyMissingMigrations(char const** migrations, char const* fileSuffix)
{
    if (!sConfig.GetBoolDefault("Database.AutoApplyMigrations", true))
        return true;

    if (!fileSuffix || !IsMigrationSuffix(fileSuffix))
    {
        sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Refusing to apply migrations for unknown database type.");
        return false;
    }

    std::set<std::string> appliedMigrations;
    if (std::unique_ptr<QueryResult> result = Query("SELECT * FROM `migrations`"))
    {
        do
        {
            if (char const* id = result->Fetch()[0].GetString())
                appliedMigrations.insert(id);
        } while (result->NextRow());
    }

    std::vector<std::string> missingMigrations;
    while (migrations && *migrations)
    {
        if (!appliedMigrations.count(*migrations))
            missingMigrations.push_back(*migrations);
        ++migrations;
    }

    if (missingMigrations.empty())
        return true;

    std::sort(missingMigrations.begin(), missingMigrations.end());

    std::string dbName = getAsyncConnection() ? getAsyncConnection()->DatabaseName() : std::string();
    if (std::unique_ptr<QueryResult> nameResult = Query("SELECT DATABASE()"))
    {
        if (char const* name = nameResult->Fetch()[0].GetString())
            dbName = name;
    }

    std::vector<std::string> const searchDirs = MigrationSearchDirs();
    std::string migrationsDir;

    sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Database `%s` is missing %u migration(s). Applying them now.",
        dbName.c_str(), static_cast<unsigned>(missingMigrations.size()));

    for (std::string const& id : missingMigrations)
    {
        if (!IsMigrationId(id))
        {
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Migration id `%s` is not a numeric timestamp. Refusing to apply it.", id.c_str());
            return false;
        }

        std::string const filename = id + "_" + fileSuffix + ".sql";
        std::string path = migrationsDir.empty() ? std::string() : JoinPath(migrationsDir, filename);
        bool const hadDir = !migrationsDir.empty();
        if (path.empty() || !FileExists(path))
            path = FindMigrationFile(searchDirs, filename, migrationsDir);

        if (!hadDir && !migrationsDir.empty())
            sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Using migration scripts from %s", migrationsDir.c_str());

        if (path.empty())
        {
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Database `%s` is missing the following migrations:", dbName.c_str());
            for (std::string const& missing : missingMigrations)
                sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "\t%s", missing.c_str());
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Could not find migration script %s.", filename.c_str());
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Set Database.MigrationsDir to the core sql/migrations folder, or place that folder next to the executable (sql/migrations) or in a parent directory of the executable, config file, or working directory.");
            return false;
        }

        std::string script;
        std::string error;
        if (!ReadFile(path, script, error))
        {
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Failed to read migration %s: %s", id.c_str(), error.c_str());
            return false;
        }

        if (script.find(id) == std::string::npos)
        {
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Migration file %s does not contain id %s. Refusing to apply it.", path.c_str(), id.c_str());
            return false;
        }

        std::vector<std::string> statements;
        if (!SplitMysqlScript(script, statements, error) || statements.empty())
        {
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Failed to parse migration %s: %s", path.c_str(), error.empty() ? "no statements" : error.c_str());
            return false;
        }

        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Applying migration %s to database `%s`...", id.c_str(), dbName.c_str());

        for (size_t i = 0; i < statements.size(); ++i)
        {
            if (!DirectExecuteScript(statements[i], error))
            {
                sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Failed to apply migration %s to database `%s` (statement %u/%u): %s",
                    id.c_str(), dbName.c_str(), static_cast<unsigned>(i + 1), static_cast<unsigned>(statements.size()), error.c_str());
                sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Statement: %s", SqlSnippet(statements[i]).c_str());
                if (error.find("max_allowed_packet") != std::string::npos || error.find("[1153]") == 0)
                    sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "The MySQL server rejected the script because it exceeds max_allowed_packet. Raise max_allowed_packet (for example to 64M) and start the server again.");
                if (PQuery("SELECT `id` FROM `migrations` WHERE `id`='%s'", id.c_str()))
                    sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Migration %s recorded its id before failing. Delete that row from `migrations` before starting again, or the server will skip the rest of the script.", id.c_str());
                return false;
            }
        }

        std::unique_ptr<QueryResult> applied = PQuery("SELECT `id` FROM `migrations` WHERE `id`='%s'", id.c_str());
        if (!applied)
        {
            sLog.Out(LOG_DBERROR, LOG_LVL_ERROR, "Migration %s ran but was not recorded in `migrations` on database `%s`.", id.c_str(), dbName.c_str());
            return false;
        }

        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "Applied migration %s.", id.c_str());
    }

    return true;
}
