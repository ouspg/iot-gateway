counter = 0
file = nil

function init()
 	   file = assert(io.open("/tmp/lua-leases", "a"))
           print("starting...")
end


function shutdown()
	   file:close()
	   print("ending.....")
end

function lease(action , lease_desc)
	 counter = counter + 1

	local line = "Lua: " .. action .. " " .. counter

	for k,v in pairs(lease_desc) do line = line .. "\n" .. k .. " " .. v  end

	file:write(line .. "\n")
	
	print(line)

end
