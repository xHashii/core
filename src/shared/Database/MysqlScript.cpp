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

#include "Database/MysqlScript.h"

namespace
{
bool IsIdentChar(char c)
{
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}

bool IsSpace(char c)
{
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

std::string TrimCopy(std::string const& value)
{
    size_t begin = 0;
    while (begin < value.size() && IsSpace(value[begin]))
        ++begin;

    size_t end = value.size();
    while (end > begin && IsSpace(value[end - 1]))
        --end;

    return value.substr(begin, end - begin);
}

bool AtStatementStart(std::string const& current)
{
    for (char c : current)
        if (!IsSpace(c))
            return false;
    return true;
}

bool StartsWithIgnoreCase(std::string const& script, size_t pos, char const* word, size_t length)
{
    if (pos + length > script.size())
        return false;

    for (size_t i = 0; i < length; ++i)
    {
        char left = script[pos + i];
        char right = word[i];
        if (left >= 'A' && left <= 'Z')
            left = static_cast<char>(left - 'A' + 'a');
        if (right >= 'A' && right <= 'Z')
            right = static_cast<char>(right - 'A' + 'a');
        if (left != right)
            return false;
    }
    return true;
}
}

bool SplitMysqlScript(std::string const& script, std::vector<std::string>& statements, std::string& error)
{
    statements.clear();
    error.clear();

    std::string delimiter = ";";
    std::string current;
    current.reserve(256);

    size_t i = 0;
    if (script.size() >= 3 &&
        static_cast<unsigned char>(script[0]) == 0xEF &&
        static_cast<unsigned char>(script[1]) == 0xBB &&
        static_cast<unsigned char>(script[2]) == 0xBF)
        i = 3;

    auto flush = [&]()
    {
        std::string statement = TrimCopy(current);
        current.clear();
        if (!statement.empty())
            statements.push_back(std::move(statement));
    };

    while (i < script.size())
    {
        if (AtStatementStart(current))
        {
            size_t j = i;
            while (j < script.size() && IsSpace(script[j]))
                ++j;

            if (j < script.size() && StartsWithIgnoreCase(script, j, "delimiter", 9) &&
                (j + 9 >= script.size() || !IsIdentChar(script[j + 9])))
            {
                j += 9;
                while (j < script.size() && (script[j] == ' ' || script[j] == '\t'))
                    ++j;

                size_t end = j;
                while (end < script.size() && script[end] != '\n' && script[end] != '\r')
                    ++end;

                std::string nextDelimiter = TrimCopy(script.substr(j, end - j));
                if (nextDelimiter.empty())
                {
                    error = "DELIMITER command is missing a delimiter";
                    return false;
                }

                delimiter = std::move(nextDelimiter);
                current.clear();
                i = end;
                while (i < script.size() && (script[i] == '\r' || script[i] == '\n'))
                    ++i;
                continue;
            }
        }

        if (!delimiter.empty() && i + delimiter.size() <= script.size() &&
            script.compare(i, delimiter.size(), delimiter) == 0)
        {
            flush();
            i += delimiter.size();
            continue;
        }

        char c = script[i];

        // mysql requires whitespace after '--' before it is a line comment.
        if (c == '-' && i + 1 < script.size() && script[i + 1] == '-')
        {
            char next = (i + 2 < script.size()) ? script[i + 2] : '\n';
            if (IsSpace(next))
            {
                while (i < script.size() && script[i] != '\n')
                    current.push_back(script[i++]);
                continue;
            }
        }

        if (c == '#')
        {
            while (i < script.size() && script[i] != '\n')
                current.push_back(script[i++]);
            continue;
        }

        if (c == '/' && i + 1 < script.size() && script[i + 1] == '*')
        {
            current.push_back(c);
            current.push_back('*');
            i += 2;
            while (i + 1 < script.size() && !(script[i] == '*' && script[i + 1] == '/'))
                current.push_back(script[i++]);
            if (i + 1 < script.size())
            {
                current.push_back(script[i++]);
                current.push_back(script[i++]);
            }
            continue;
        }

        if (c == '\'' || c == '"' || c == '`')
        {
            char quote = c;
            current.push_back(c);
            ++i;
            while (i < script.size())
            {
                char quoted = script[i];
                current.push_back(quoted);
                ++i;
                if (quoted == '\\' && i < script.size())
                {
                    current.push_back(script[i++]);
                    continue;
                }
                if (quoted == quote)
                {
                    if (i < script.size() && script[i] == quote)
                    {
                        current.push_back(script[i++]);
                        continue;
                    }
                    break;
                }
            }
            continue;
        }

        current.push_back(c);
        ++i;
    }

    flush();
    return true;
}

#ifdef MANGOS_TEST_MYSQL_SCRIPT
#include <dirent.h>
#include <fstream>
#include <iostream>

namespace
{
bool StartsWith(std::string const& value, char const* prefix)
{
    size_t i = 0;
    while (i < value.size() && IsSpace(value[i]))
        ++i;
    size_t length = 0;
    while (prefix[length])
        ++length;
    if (i + length > value.size())
        return false;
    for (size_t k = 0; k < length; ++k)
    {
        char left = value[i + k];
        char right = prefix[k];
        if (left >= 'a' && left <= 'z')
            left = static_cast<char>(left - 'a' + 'A');
        if (right >= 'a' && right <= 'z')
            right = static_cast<char>(right - 'a' + 'A');
        if (left != right)
            return false;
    }
    return true;
}

bool ReadAll(std::string const& path, std::string& out)
{
    std::ifstream in(path.c_str(), std::ios::in | std::ios::binary);
    if (!in)
        return false;
    in.seekg(0, std::ios::end);
    std::streamoff size = in.tellg();
    if (size < 0)
        return false;
    in.seekg(0, std::ios::beg);
    out.resize(static_cast<size_t>(size));
    return size == 0 || static_cast<bool>(in.read(&out[0], size));
}
}

int main(int argc, char** argv)
{
    if (argc != 2)
    {
        std::cerr << "Usage: test_mysql_script <sql/migrations>\n";
        return 2;
    }

    std::string sample =
        "DROP PROCEDURE IF EXISTS add_migration;\n"
        "DELIMITER ??\n"
        "CREATE PROCEDURE `add_migration`()\n"
        "BEGIN\n"
        "  SET @q = 'ucht was??';\n"
        "  SELECT 1;\n"
        "END??\n"
        "DELIMITER ;\n"
        "CALL add_migration();\n"
        "DROP PROCEDURE IF EXISTS add_migration;\n";

    std::vector<std::string> statements;
    std::string error;
    if (!SplitMysqlScript(sample, statements, error) || statements.size() != 4)
    {
        std::cerr << "synthetic split failed: " << statements.size() << " " << error << "\n";
        return 1;
    }
    if (statements[1].find("ucht was??") == std::string::npos || statements[1].find("CALL") != std::string::npos)
    {
        std::cerr << "synthetic procedure was split inside a string\n";
        return 1;
    }

    DIR* dir = opendir(argv[1]);
    if (!dir)
    {
        std::cerr << "cannot open " << argv[1] << "\n";
        return 1;
    }

    int files = 0;
    int bad = 0;
    while (dirent* entry = readdir(dir))
    {
        std::string name = entry->d_name;
        if (name.size() < 5 || name.substr(name.size() - 4) != ".sql")
            continue;

        std::string id = name.substr(0, name.find('_'));
        std::string path = std::string(argv[1]) + "/" + name;
        std::string script;
        if (!ReadAll(path, script))
        {
            std::cerr << "read failed " << path << "\n";
            ++bad;
            continue;
        }

        if (!SplitMysqlScript(script, statements, error))
        {
            std::cerr << "split failed " << name << ": " << error << "\n";
            ++bad;
            continue;
        }

        int creates = 0;
        int calls = 0;
        for (std::string const& statement : statements)
        {
            if (StartsWith(statement, "CREATE PROCEDURE") || StartsWith(statement, "CREATE DEFINER"))
                ++creates;
            if (StartsWith(statement, "CALL "))
                ++calls;
            if (statement.find("CALL add_migration") != std::string::npos && StartsWith(statement, "CREATE"))
            {
                std::cerr << "call leaked into procedure " << name << "\n";
                ++bad;
            }
        }

        if (creates != 1 || calls != 1)
        {
            std::cerr << "bad shape " << name << " statements=" << statements.size()
                      << " creates=" << creates << " calls=" << calls << "\n";
            ++bad;
        }
        else if (statements[creates == 1 ? 0 : 0].empty())
        {
            ++bad;
        }
        else
        {
            bool sawId = false;
            for (std::string const& statement : statements)
                if (StartsWith(statement, "CREATE") && statement.find(id) != std::string::npos)
                    sawId = true;
            if (!sawId)
            {
                std::cerr << "id missing from procedure " << name << "\n";
                ++bad;
            }
        }

        ++files;
        if (bad > 8)
            break;
    }
    closedir(dir);

    std::cout << "files=" << files << " bad=" << bad << "\n";
    return bad == 0 && files > 0 ? 0 : 1;
}
#endif
