-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.admin.status", package.seeall)

sql = require("luasql.sqlite3")

function index()
	entry({"admin", "status"}, alias("admin", "status", "overview"), _("Status"), 20).index = true
	entry({"admin", "status", "overview"}, template("admin_status/index"), _("Overview"), 1)
	entry({"admin", "status", "iptables"}, call("action_iptables"), _("Firewall"), 2).leaf = true
	entry({"admin", "status", "routes"}, template("admin_status/routes"), _("Routes"), 3)
	entry({"admin", "status", "syslog"}, call("action_syslog"), _("System Log"), 4)
	entry({"admin", "status", "dmesg"}, call("action_dmesg"), _("Kernel Log"), 5)
	entry({"admin", "status", "processes"}, cbi("admin_status/processes"), _("Processes"), 6)

	entry({"admin", "status", "realtime"}, alias("admin", "status", "realtime", "load"), _("Realtime Graphs"), 7)

	entry({"admin", "status", "realtime", "load"}, template("admin_status/load"), _("Load"), 1).leaf = true
	entry({"admin", "status", "realtime", "load_status"}, call("action_load")).leaf = true

	entry({"admin", "status", "realtime", "bandwidth"}, template("admin_status/bandwidth"), _("Traffic"), 2).leaf = true
	entry({"admin", "status", "realtime", "bandwidth_status"}, call("action_bandwidth")).leaf = true

	entry({"admin", "status", "realtime", "wireless"}, template("admin_status/wireless"), _("Wireless"), 3).leaf = true
	entry({"admin", "status", "realtime", "wireless_status"}, call("action_wireless")).leaf = true

	entry({"admin", "status", "realtime", "connections"}, template("admin_status/connections"), _("Connections"), 4).leaf = true
	entry({"admin", "status", "realtime", "connections_status"}, call("action_connections")).leaf = true

	entry({"admin", "status", "realtime", "connections_map"}, template("admin_status/connection_map"), _("Connection map"), 5).leaf = true
	entry({"admin", "status", "realtime", "connection_geoip_cache_query"}, call("action_connection_cache_query")).leaf = true
	entry({"admin", "status", "realtime", "connection_geoip_db_query"}, call("action_connection_geoip_db_query")).leaf = true

	entry({"admin", "status", "nameinfo"}, call("action_nameinfo")).leaf = true
end

function action_syslog()
	local syslog = luci.sys.syslog()
	luci.template.render("admin_status/syslog", {syslog=syslog})
end

function action_dmesg()
	local dmesg = luci.sys.dmesg()
	luci.template.render("admin_status/dmesg", {dmesg=dmesg})
end

function action_iptables()
	if luci.http.formvalue("zero") then
		if luci.http.formvalue("zero") == "6" then
			luci.util.exec("ip6tables -Z")
		else
			luci.util.exec("iptables -Z")
		end
		luci.http.redirect(
			luci.dispatcher.build_url("admin", "status", "iptables")
		)
	elseif luci.http.formvalue("restart") == "1" then
		luci.util.exec("/etc/init.d/firewall reload")
		luci.http.redirect(
			luci.dispatcher.build_url("admin", "status", "iptables")
		)
	else
		luci.template.render("admin_status/iptables")
	end
end

function action_bandwidth(iface)
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -i %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_wireless(iface)
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -r %q 2>/dev/null" % iface)
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_load()
	luci.http.prepare_content("application/json")

	local bwc = io.popen("luci-bwc -l 2>/dev/null")
	if bwc then
		luci.http.write("[")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end
end

function action_connections()
	local sys = require "luci.sys"

	luci.http.prepare_content("application/json")

	luci.http.write("{ connections: ")
	luci.http.write_json(sys.net.conntrack())

	local bwc = io.popen("luci-bwc -c 2>/dev/null")
	if bwc then
		luci.http.write(", statistics: [")

		while true do
			local ln = bwc:read("*l")
			if not ln then break end
			luci.http.write(ln)
		end

		luci.http.write("]")
		bwc:close()
	end

	luci.http.write(" }")
end

function action_connection_cache_query()
	local sys = require "luci.sys"

	luci.http.prepare_content("application/json")

	local conns = _add_integer_ips(sys.net.conntrack()) -- get current connections, append IP addresses in integer form

	local unique_ips = {} -- will contain the unique IPs as keys

	for i, conn in ipairs(conns) do
		-- Optimization: filter local IPs, but we'll skip it for this time.
		-- Action point: /usr/lib/lua/luci/controller/admin/status.lua:157: table index is nil
		if conn.src_int and conn.dst_int then
			unique_ips[tostring(conn.src_int)] = true
			unique_ips[tostring(conn.dst_int)] = true
		end
	end

	local geoip_query_results = {}

	local query_table = {"SELECT * FROM ipv4_city_blocks_cache WHERE "}

	for ip in pairs(unique_ips) do
		table.insert(query_table, "(network_start_integer <= " .. ip .. " AND network_last_integer >= " .. ip ..") OR ")
	end

	local query_str = string.sub(table.concat(query_table), 1, -5) .. ";" 

	table.insert(geoip_query_results, _db_query(query_str))

	luci.http.write_json({conns, geoip_query_results})

end

function action_connection_geoip_db_query(...)

	luci.http.prepare_content("application/json")

	-- Get the IPs (=the rest of the URL foo/123456/7890)
	local i
	local unique_ips = {} -- will contain the unique IPs as keys
	for i = 1, select('#', ...) do
		local addr = select(i, ...) 
		if tonumber(addr) then -- tonumber to ensure number, not for example partial SQL query
			unique_ips[addr] = true
		end
	end

	local ip_buckets = _bucketize_ips(unique_ips)

	local geoip_query_results = {}

	-- Construct DB string to query the rows from the db, one bucket at a time
	for table_name, ip_array in pairs(ip_buckets) do
		if #ip_array > 0 then
			local query_table = {"SELECT * FROM " .. table_name .. " WHERE "}

			for i, ip in pairs(ip_array) do
				table.insert(query_table, "(network_start_integer <= " .. ip .. " AND network_last_integer >= " .. ip ..") OR ")
			end

			local query_str = string.sub(table.concat(query_table), 1, -5) .. ";" -- create query string, cut extra " OR" from the end, add semicolon

			--table.insert(geoip_query_results, query_str)
			table.insert(geoip_query_results, _db_query(query_str))
			--_db_query(query_str)
		end
	end

	-- Put the found rows into the cache db.
	local query_table = { "INSERT INTO ipv4_city_blocks_cache (network_start_integer, ", 
		"network_last_integer, geoname_id, registered_country_geoname_id, represented_country_geoname_id, ",
		"is_anonymous_proxy, is_satellite_provider, postal_code, latitude, longitude) VALUES " }	
	for i, db_row_tbl in pairs(geoip_query_results) do
		local db_row = db_row_tbl[1]
		if db_row then
			if db_row["network_start_integer"] and db_row["network_last_integer"] and db_row["latitude"] and db_row["longitude"] then
				table.insert(query_table, "( ")
				table.insert(query_table, 'CAST(' .. db_row["network_start_integer"] .. ' AS INTEGER), ') 
				table.insert(query_table, 'CAST(' .. db_row["network_last_integer"] .. ' AS INTEGER), ')   
				table.insert(query_table, db_row["geoname_id"] .. ", ")
				table.insert(query_table, db_row["registered_country_geoname_id"] .. ", ")
				table.insert(query_table, db_row["represented_country_geoname_id"] .. ", ")
				table.insert(query_table, db_row["is_anonymous_proxy"] .. ", ")
				table.insert(query_table, db_row["is_satellite_provider"] .. ", ")
				table.insert(query_table, db_row["postal_code"] .. ", ")
				table.insert(query_table, db_row["latitude"] .. ", ")
				table.insert(query_table, db_row["longitude"] .. "), ")
			end
		end
	end
	local query_str = string.sub(table.concat(query_table), 1, -3) .. ";" -- Remove excess ", " and add semicolon.
	query_str = string.gsub(query_str, ", ,", ", 0,"); -- hack to fix problem with empty values

	local cur = _execute_sql(query_str)

	-- Return the found rows to the frontend
	luci.http.write_json(geoip_query_results)
end

function action_nameinfo(...)
	local i
	local rv = { }
	for i = 1, select('#', ...) do
		local addr = select(i, ...)
		local fqdn = nixio.getnameinfo(addr)
		rv[addr] = fqdn or (addr:match(":") and "[%s]" % addr or addr)
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end

function _add_integer_ips(conns)
	for i, conn in ipairs(conns) do
		local saddr = conn.src
		local snum = 0
		local daddr = conn.dst
		local dnum = 0
		if conn.layer3 == "ipv4" then
			saddr:gsub("%d+", function(s) snum = snum * 256 + tonumber(s) end)
			daddr:gsub("%d+", function(s) dnum = dnum * 256 + tonumber(s) end)
			conn.src_int = snum
			conn.dst_int = dnum
		elseif conn.layer3 == "ipv6" then
			-- TODO: ipv6 -> integer
		end
	end
	return conns
end

function _bucketize_ips(ip_bag)
	local result_table = {}
	local range_table = {
{ "ipv4_city_blocks_0", 16777216,204718079 },
{ "ipv4_city_blocks_1", 204718080,410046079 },
{ "ipv4_city_blocks_2", 410046080,629299199 },
{ "ipv4_city_blocks_3", 629299200,835490815 },
{ "ipv4_city_blocks_4", 835490816,979914751 },
{ "ipv4_city_blocks_5", 979914752,1063263231 },
{ "ipv4_city_blocks_6", 1063263232,1110522367 },
{ "ipv4_city_blocks_7", 1110522368,1144413439 },
{ "ipv4_city_blocks_8", 1144413440,1178513407 },
{ "ipv4_city_blocks_9", 1178513408,1207596543 },
{ "ipv4_city_blocks_10", 1207596544,1238725631 },
{ "ipv4_city_blocks_11", 1238725632,1268037000 },
{ "ipv4_city_blocks_12", 1268037001,1309656831 },
{ "ipv4_city_blocks_13", 1309656832,1339945983 },
{ "ipv4_city_blocks_14", 1339945984,1374325247 },
{ "ipv4_city_blocks_15", 1374325248,1408035015 },
{ "ipv4_city_blocks_16", 1408035016,1443475583 },
{ "ipv4_city_blocks_17", 1443475584,1475006847 },
{ "ipv4_city_blocks_18", 1475006848,1511374591 },
{ "ipv4_city_blocks_19", 1511374592,1547755775 },
{ "ipv4_city_blocks_20", 1547755776,1586068223 },
{ "ipv4_city_blocks_21", 1586068224,1633480703 },
{ "ipv4_city_blocks_22", 1633480704,1701306879 },
{ "ipv4_city_blocks_23", 1701306880,1817462783 },
{ "ipv4_city_blocks_24", 1817462784,1924881663 },
{ "ipv4_city_blocks_25", 1924881664,2056577955 },
{ "ipv4_city_blocks_26", 2056577956,2304113663 },
{ "ipv4_city_blocks_27", 2304113664,2619492351 },
{ "ipv4_city_blocks_28", 2619492352,2905659903 },
{ "ipv4_city_blocks_29", 2905659904,2964592639 },
{ "ipv4_city_blocks_30", 2964592640,3038656511 },
{ "ipv4_city_blocks_31", 3038656512,3136602111 },
{ "ipv4_city_blocks_32", 3136602112,3188235263 },
{ "ipv4_city_blocks_33", 3188235264,3262473863 },
{ "ipv4_city_blocks_34", 3262473864,3350315007 },
{ "ipv4_city_blocks_35", 3350315008,3414589183 },
{ "ipv4_city_blocks_36", 3414589184,3494584319 },
{ "ipv4_city_blocks_37", 3494584320,3569762175 },
{ "ipv4_city_blocks_38", 3569762176,3648540159 },
{ "ipv4_city_blocks_39", 3648540160,3758096383 }	
}
	for i = 0, 39 do
		result_table["ipv4_city_blocks_" .. i] = {}
	end

	for ip in pairs(ip_bag) do
		for k, range_entry in pairs(range_table) do
			if tonumber(ip) >= range_entry[2] and tonumber(ip) <= range_entry[3] then
				table.insert(result_table[range_entry[1]], tonumber(ip))
			end
		end
	end
	return result_table
end

function _db_query(query_str)
	-- TODO: Replace beginning with _execute_sql
	local env = sql.sqlite3()
	local db = env:connect("/mnt/sda1/geolite/geolite2_cities_integers_opt.db", 5000) 	-- FIXME: this should come from configs somewhere. 
																						-- Number=wait for db lock timeout in ms.
	
	-- luci.http.write_json({query_str})

	do_log("_db_query - query_str: " .. query_str)

	local cur = db:execute(query_str)
	
	local result_table = {}
	
	local col_names = {"network_start_integer", "network_last_integer", "geoname_id", "registered_country_geoname_id", 
						"represented_country_geoname_id", "is_anonymous_proxy", "is_satellite_provider", "postal_code", "latitude", "longitude" }
	local row = cur:fetch({}, "a")
	while row do
		local result_row = {}
		for i, col_name in pairs(col_names) do
			if col_name == "network_start_integer" or col_name == "network_last_integer" then
				result_row[col_name] = unsign(row[col_name])
			else
				result_row[col_name] = row[col_name]
			end
		end
		table.insert(result_table, result_row)
		row = cur:fetch(row, "a")
	end
	--luci.http.write_json(result_table)

	env:close()
	return result_table
end

function _execute_sql(query_str)
	-- TODO: Sanitize queries somehow
	local env = sql.sqlite3()
	local db = env:connect("/mnt/sda1/geolite/geolite2_cities_integers_opt.db", 5000) 	-- FIXME: this should come from configs somewhere. 
																						-- Number=wait for db lock timeout in ms.
	
	-- luci.http.write_json({query_str})
	local ret_val = db:execute(query_str)

	env:close()

	do_log("_execute_sql - query_str: " .. query_str)

	return ret_val
end

function do_log(log_text)
--	require "nixio"
--	local dbg = io.open("/tmp/statusdebug.txt", "a+")
--	dbg:write(log_text)
--	dbg:close()
end

function unsign(n)
    if n < 0 then
        n = 4294967296 + n
    end
    return n
end
