--------------------------------------------------------------------------------
-- resty_mysql.lua, v0.3.1: DB module for connecting and querying through MySQL on openresty servers
-- This file is a part of Sailor project
-- Copyright (c) 2014 Etiene Dalcol <dalcol@etiene.net>
-- License: MIT
-- http://sailorproject.org
--------------------------------------------------------------------------------

local main_conf = require "conf.conf"
local conf = main_conf.db[main_conf.sailor.environment]
local pgsql = require "resty.postgres"
local base = require("sailor.db.base")
-- Our db object
local db = {instance = nil, transaction = false}

local escape = function(q)
	if type(q) == "string" then
		return "'" .. tostring(q) .. "'"
	elseif type(q) == "table" then
		for k,v in pairs(q) do
			q[k] = "'" .. tostring(v) .. "'"
		end
		return
	end
	return q
end

-- Init parent
local interpolate_query = base.init(escape)

function db.instantiate()
	if not db.instance then
		local instance, err = pgsql:new()
    	if not instance then
        	error("Failed to instantiate pgsql: ".. (err or ''))
    	end
    	db.instance = instance
	end
end

-- Creates the connection of the instance
function db.connect()
	if db.transaction then return end
	db.instantiate()
	conf.host = string.gsub(conf.host, "localhost", "127.0.0.1")
	local ok, err, errno, sqlstate = db.instance:connect{
        host = conf.host,
        database = conf.dbname,
        user = conf.user,
        password = conf.pass
    }
    if not ok then
	   error("Failed to connect to database: ".. tostring(err)..": ".. (errno or '') .." "..(sqlstate or ''))
	end
end

-- Closes the connection of the instance
function db.close()
	if db.transaction then return end
	local ok, err = db.instance:close()
    if not ok then
        error("Failed to close database connection: ".. err)
    end
    db.instance = nil
end

-- Starts a transation
function db.begin_transaction()
	db.connect()
	local query = "START TRANSACTION;"
	db.query(query)
	db.transaction = true
end

-- Commits a transaction, everything went alright
function db.commit()
	db.query("COMMIT;")
	db.transaction = false
	db.close()
end

-- Rollback everything done during transaction
function db.rollback()
	db.query("ROLLBACK;")
	db.transaction = false
	db.close()
end


-- Runs a query
-- @param query string: the query to be executed
-- @return table: a cursor
function db.query(query, ...)
	local query = interpolate_query(query, ...)
	local res, err, errno, sqlstate = db.instance:query(query)
    if not res then
    	print("executed query: ", query)
        error("Bad result: ".. err ..": ".. (errno or '') .." "..(sqlstate or ''))
    end
    return res
end


-- Truncates a table
-- @param table_name string: the name of the table to be truncated
function db.truncate(table_name)
	local query = 'truncate table ' .. table_name .. ' RESTART IDENTITY CASCADE;'
	return db.query(query)
end

function db.query_insert(query,key)
	key = key or 'id'
	query = query .. " RETURNING id; "
	local res =  db.query(query)
	if #res == 1 then
		return res[1][key]
	end
	return res
end

-- Runs a query and get one single value
-- @param query string: the query to be executed
-- @return string | number: the result
function db.query_one(query, ...)
	local res = db.query(query, ...)
	local value
	if next(res) then
		for _,v in pairs(res[1]) do value = v end
	end
	return value
end

-- Gets columns
-- @param table_name string: the name of the table
-- @return table{strings}, string (primary key column name)
function db.get_columns(table_name)
	local columns = {}
	local key
	local query_col = "SELECT column_name FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = '"..table_name.."';"
	local query_key = "SELECT column_name FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE table_name = '"..table_name.."';"

	for _,v in ipairs(db.query(query_col)) do
		columns[#columns+1] = v.column_name
	end
	key = db.query_one(query_key)
	return columns,key
end

-- Checks if a table exists
-- @param table_name string: the name of the table
-- @return boolean
function db.table_exists(table_name)
 	local query = "SELECT relname FROM pg_class WHERE relname = ?;" 	
	local res = db.query_one(query, table_name)
	return res == table_name
end

-- Escapes a string for use in a query as column or table name.
-- @param table_name string: the name of the table
function db.escape_table(table_name)
	table_name = tostring(table_name)
	return '"' .. (table_name:gsub('"', '""')) .. '"'
end

-- For compat
function db.escape(value)
	return escape(value)
end

-- For test
function db.interpolate_query(query, ...)
	return interpolate_query(query,  ...)
end
return db