
--database data should not be within the lua stack
--old database wasn't flexible for infinite arrays and dictionaries
--[[
	database.Lmao = 'LMAOOOO';
	database:Push('lmao', 'LMAOOOO');


	database.A.B.C.D.Lmao = 'Test';
	database:Push('A>B>C>D', 'Test');

	so database should be the universal statement, while the segments are only part of the database
	database:Push('lmao>yeet');
]]
local State = {};
local ClientState = {};
local SegmentStack = {};
local Memory = {};
local json = require('json');

local file_exists = function(name)
	local f = io.open(name, 'r');
	if (f ~= nil) then 
		io.close(f);
		return true;
	end;
	return false;
end;

local StringToBytecodeArray = function(str)
    local BytecodeArray = {};
    for i = 1, str:len() do
        local character = str:sub(i, i);
        BytecodeArray[i] = string.byte(character);
    end;
    return BytecodeArray;
end;

local BytecodeArrayToString = function(arr)
    local String = {};
    for i = 1, #arr do
        String[i] = string.char(arr[i]);
    end;
    return table.concat(String, '');
end;
--directories are super weird here
--setfenv(loadfile([[C:\Users\phant\Desktop\DBTest\Database.lua]]),getfenv())()
--we're trying to wrap everything
--we have a segment inheritance issue

State.NameValid = function(self, name)
    if (name:find('>') ~= nil) then
        error('Database name cannot contain >');
    end;
end;

State.GetDatabase = function(self, name)
    if (Memory[name] ~= nil) then
        return Memory[name];
    end;
    self:NameValid(name);
	local path = name..'.addb';
	if (file_exists(path) == true) then
		local getCurrentDatabase = function()
			local db = io.open(path, 'r');
			local str = db:read('*all');
			db:close();
			return str;
		end;
        local dbSegment = {};
        local SegmentTree = {};
        local GetSegmentByDirectory = function(previousDirectory, name)
            return SegmentTree[dbSegment:AttachKey(previousDirectory, name)];
        end;
        dbSegment.AttachKey = function(self, previousDirectory, index)
            return name..':'..previousDirectory..'>'..index;
        end;

        dbSegment.Push = function(self, indexPath, value)
			local current = getCurrentDatabase();
			local currentJson = json.decode(current);
			local arr = StringToBytecodeArray(indexPath);
			local pathsOrder = {};
			local currentPath = 1;
			for i = 1, #arr do
				local byte = arr[i];
                if (pathsOrder[currentPath] ~= nil and (byte == string.byte'>' or i == #arr)) then
                    if (i == #arr and pathsOrder[currentPath] ~= nil) then
                        table.insert(pathsOrder[currentPath], byte);
                    end;
                    pathsOrder[currentPath] = BytecodeArrayToString(pathsOrder[currentPath]);
					currentPath = currentPath + 1;
				else
					if (pathsOrder[currentPath] == nil) then
						pathsOrder[currentPath] = {};
					end;
					table.insert(pathsOrder[currentPath], byte);
				end;
            end;
			local currentState = currentJson;
			for i, v in next, pathsOrder do
				if (pathsOrder[i + 1] ~= nil) then
                    currentState = currentState[v];
                    if (currentState == nil) then
                        break;
                    end;
				else
					currentState[v] = value;
				end;
			end;
			local db = io.open(path, 'w+');
			db:write(json.encode(currentJson), '\n');
			db:close();
        end;
        dbSegment.Pull = function(self, indexPath)
			local current = getCurrentDatabase();
			local currentJson = json.decode(current);
			local arr = StringToBytecodeArray(indexPath);
			local pathsOrder = {};
			local currentPath = 1;
			for i = 1, #arr do
				local byte = arr[i];
                if (pathsOrder[currentPath] ~= nil and (byte == string.byte'>' or i == #arr)) then
                    if (i == #arr and pathsOrder[currentPath] ~= nil) then
                        table.insert(pathsOrder[currentPath], byte);
                    end;
                    pathsOrder[currentPath] = BytecodeArrayToString(pathsOrder[currentPath]);
					currentPath = currentPath + 1;
				else
					if (pathsOrder[currentPath] == nil) then
						pathsOrder[currentPath] = {};
					end;
					table.insert(pathsOrder[currentPath], byte);
				end;
            end;
			local currentState = currentJson;
            for i, v in next, pathsOrder do
                if (currentState[v] ~= nil) then
                    currentState = currentState[v];
                else
                    currentState = nil;
                    break;
                end;
			end;
			return currentState;
		end;
		dbSegment.Delete = function(self, indexPath)
			self:Push(indexPath, nil);
		end;
        
        dbSegment.createAPI = function(self)
            local Tree = {};
            local TreeMeta = setmetatable(Tree, {
                __index = function(self, index)
                    if (dbSegment:Pull(index) ~= nil) then --if it exists
                        if (GetSegmentByDirectory('', index) == nil) then
                            return dbSegment:AttachSegment(true, '', index);
                        else
                            return GetSegmentByDirectory('', index);
                        end;
                    end;
                end;
                __newindex = function(self, index, value)
                    local segment;
                    if (dbSegment:Pull(index) ~= nil) then --if it exists
                        if (GetSegmentByDirectory('', index) == nil) then
                            return dbSegment:AttachSegment(true, '', index)('SetValue', value);
                        else
                            return (function() return GetSegmentByDirectory('', index) or function() end; end)()('SetValue', value);
                        end;
                    elseif (dbSegment:Pull(index) == nil) then
                        return dbSegment:AttachSegment(true, '', index)('SetValue', value);
                    end;
                end;
                __tostring = function() return 'Database: '..name; end;
            });

            SegmentStack[dbSegment] = SegmentTree;
            return Tree;
        end;

        dbSegment.AttachSegment = function(self, isBaseSegment, previousDirectory, name)
            if (SegmentTree[dbSegment:AttachKey(previousDirectory, name)] ~= nil) then
                return SegmentTree[dbSegment:AttachKey(previousDirectory, name)];
            end;
            local seg = newproxy(true);
            local address = tostring(seg);
            local meta = getmetatable(seg);
            SegmentTree[dbSegment:AttachKey(previousDirectory, name)] = seg;
            local currentDirectory = (function()
                if (isBaseSegment == false) then
                    return previousDirectory..'>'..name;
                else
                    return name;
                end;
            end)();
            meta.__index = function(self, index)
                if (dbSegment:Pull(currentDirectory..'>'..index) ~= nil) then --if it exists
                    if (GetSegmentByDirectory(currentDirectory, index) == nil) then
                        return dbSegment:AttachSegment(false, currentDirectory, index);
                    else
                        return GetSegmentByDirectory(currentDirectory, index);
                    end;
                end;
            end;
            meta.__newindex = function(self, index, value)
                local segment;
                if (dbSegment:Pull(currentDirectory..'>'..index) ~= nil) then --if it exists
                    if (GetSegmentByDirectory(currentDirectory, index) == nil) then
                        return dbSegment:AttachSegment(false, currentDirectory, index)('SetValue', value);
                    else
                        return (function() return GetSegmentByDirectory(currentDirectory, index) or function() end; end)()('SetValue', value);
                    end;
                elseif (dbSegment:Pull(currentDirectory..'>'..index) == nil) then
                    return dbSegment:AttachSegment(false, currentDirectory, index)('SetValue', value);
                end;
            end;
            meta.__call = function(self, index, value) --this part is somewhat weird????
                if (type(index):lower() == 'string') then
                    if (index:lower() == 'getname') then
                        return name;
                    elseif (index:lower() == 'setvalue') then
                        return dbSegment:Push(currentDirectory, value);
                    elseif (index:lower() == 'getvalue') then
                        return dbSegment:Pull(currentDirectory);
                    elseif (index:lower() == 'getaddress') then
                        return address;
                    end;
                end;
            end;
            meta.__tostring = function() 
                return tostring(dbSegment:Pull(currentDirectory));
            end;
            return seg;
        end;
        local db = dbSegment:createAPI();
        Memory[name] = db;
        return db;
	end;
end;

State.DeleteDatabase = function(self,  name)
    local path = name..'.addb';
    if (file_exists(path) == true) then
        os.remove(path);
    end;
end;

State.CreateDatabase = function(self, name)
    local path = name..'.addb';
	if (file_exists(path) == false) then
		local newDatabase = io.open(path, 'w+');
		newDatabase:write('[]', '\n');
		newDatabase:close();
	end;
    return self:GetDatabase(name);
end;

return State;