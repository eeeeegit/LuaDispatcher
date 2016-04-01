function class(classname, super)
    local superType = type(super)
    local cls

    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}

        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end

        cls.__cname = classname
        cls.__ctype = 1

        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end

    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super
        else
            cls = {ctor = function() end}
        end

        cls.__cname = classname
        cls.__ctype = 2 -- lua
        cls.__index = cls

        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end

    return cls
end



--[[
@brief:事件分发器
@by 李俊
]]
--[[
例如我在主场景中添加了一个长监听函数
我们需要
1.声明自己的一个事件
local EVENT_UPDAT_USER_GOLD = "EVENT_UPDAT_USER_GOLD"
2.声明自己事件回调的函数
local function onUpdateUserGold(gold)
    BUI:setText(KW_BFNT_USER_GOLD,gold)
end
3.往全局事件分发器中添加函数
DispatcherUtils.addEventListener(EVENT_UPDAT_USER_GOLD,onUpdateUserGold)
4.在别的类中触发事件
DispatcherUtils.dispatchEvent(EVENT_UPDAT_USER_GOLD,"666666666")

用于实现消息订阅模式。为消息源和订阅者解耦合。例如UI只需要订阅自己的更新事件。
而service层只需要告诉分发器我发布的消息。
]]--
local Dispatcher = class("Dispatcher")
function Dispatcher:ctor()
	self._eventDispatcher = {}
end
-------------------------------------------
--订阅某个事件的常驻监听,该监听不会自动删除,适用于长监听
--@param event_name 事件名称
--@param func 监听函数
--@return listener 监听器
-------------------------------------------
function Dispatcher:addEventListener(event_name,func)
    local listener = { e=event_name , f=func }
	self._eventDispatcher[listener] = false 
    return listener
end

-------------------------------------------
--安全的订阅某个事件的常驻监听,并且会做安全检查,防止相同的监听添加,该监听不会自动删除,适用于长监听
--@param event_name 事件名称
--@param func 监听函数
--@return listener 监听器
-------------------------------------------
function Dispatcher:addEventListenerSafe(event_name,func)
    for k, _ in pairs(self._eventDispatcher) do
		if(k.e == event_name and k.f == func) then
			return k
		end
	end
	return self:addEventListener(event_name,func)
end

-------------------------------------------
--订阅某个事件的自动监听,该种监听在收到一次后会自动将自己删除,适用于一次性监听
--@param event_name 事件名称
--@param func 监听函数
-------------------------------------------
function Dispatcher:addAutoEventListener(event_name,func)
    local listener = { e=event_name , f=func}  
    self._eventDispatcher[listener] = true 
end

-------------------------------------------
--触发某个事件
--@param event_name 事件名称o(n)
--@param ... 触发事件带出的参数
-------------------------------------------
function Dispatcher:dispatchEvent(event_name,...)
    local gc = {}
	local m = self._eventDispatcher
    for k, v in pairs(self._eventDispatcher) do
        if(k.e==event_name) then
            k.f(...)
            if v then
                gc[#gc+1] = k
            end
        end
    end
    for _,v in ipairs(gc) do
        self:removeEventListener(v)
    end
end

-------------------------------------------
--从事件分发器中删除监听器o(1)
--@param listener 监听器
-------------------------------------------
function Dispatcher:removeEventListener(listener)
    self._eventDispatcher[listener] = nil 
end

----------------------------------------------------------
--[[
事件队列池，采用hash算法
MAX_DISPATCHER 表示当前的事件队列条数。
]]--
----------------------------------------------------------
local DispatcherUtils = {}
local MAX_DISPATCHER = 10

local function hashCode(s)
	local h = 0
	if(h==0 and #s>0) then
		for i=1,#s do
			h = 31*h + string.byte(s,i,i)
		end
	end
	return h
end	

local function getIndex(s)
	return math.mod(hashCode(s),MAX_DISPATCHER) + 1 
end

local function getDispatcherByEvent(event_name)
	local index =  getIndex(event_name)
	DispatcherUtils[index] = DispatcherUtils[index] or Dispatcher.new()
	return DispatcherUtils[index]
end
-------------------------------------------
--订阅某个事件的常驻监听,该监听不会自动删除,适用于长监听
--@param event_name 事件名称
--@param func 监听函数
--@return listener 监听器
-------------------------------------------
function DispatcherUtils.addEventListener(event_name,func)
	return getDispatcherByEvent(event_name):addEventListener(event_name,func)
end

-------------------------------------------
--安全的订阅某个事件的常驻监听,并且会做安全检查,防止相同的监听添加,该监听不会自动删除,适用于长监听
--@param event_name 事件名称
--@param func 监听函数
--@return listener 监听器
-------------------------------------------
function DispatcherUtils.addEventListenerSafe(event_name,func)
	return getDispatcherByEvent(event_name):addEventListenerSafe(event_name,func)
end

-------------------------------------------
--订阅某个事件的自动监听,该种监听在收到一次后会自动将自己删除,适用于一次性监听
--@param event_name 事件名称
--@param func 监听函数
-------------------------------------------
function DispatcherUtils.addAutoEventListener(event_name,func)
    getDispatcherByEvent(event_name):addAutoEventListener(event_name,func)
end

-------------------------------------------
--触发某个事件
--@param event_name 事件名称
--@param ... 触发事件带出的参数
-------------------------------------------
function DispatcherUtils.dispatchEvent(event_name,...)
    getDispatcherByEvent(event_name):dispatchEvent(event_name,...) 
end

-------------------------------------------
--从事件分发器中删除监听器
--@param listener 监听器
-------------------------------------------
function DispatcherUtils.removeEventListener(listener)
    getDispatcherByEvent(listener.e):removeEventListener(listener) 
end


function hello()
	print("hello")
end
function heihei(msg)
	print(msg)
end


--[[
for test 
	
local ss = Dispatcher.new()
for i=1,1000 do
	ss:addEventListener("KW_MY_"..i,hello)
end
local x = os.clock()
ss:dispatchEvent("KW_MY_"..1000)
local y = os.clock()
print(y-x)


for i=1,1000 do
	DispatcherUtils.addEventListener("KW_MY_"..i,hello)
end
local x = os.clock()
DispatcherUtils.dispatchEvent("KW_MY_"..1000)
local y = os.clock()

print(y-x)
]]--