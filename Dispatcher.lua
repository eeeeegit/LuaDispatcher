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
@brief:�¼��ַ���
@by �
]]
--[[
���������������������һ������������
������Ҫ
1.�����Լ���һ���¼�
local EVENT_UPDAT_USER_GOLD = "EVENT_UPDAT_USER_GOLD"
2.�����Լ��¼��ص��ĺ���
local function onUpdateUserGold(gold)
    BUI:setText(KW_BFNT_USER_GOLD,gold)
end
3.��ȫ���¼��ַ�������Ӻ���
DispatcherUtils.addEventListener(EVENT_UPDAT_USER_GOLD,onUpdateUserGold)
4.�ڱ�����д����¼�
DispatcherUtils.dispatchEvent(EVENT_UPDAT_USER_GOLD,"666666666")

����ʵ����Ϣ����ģʽ��Ϊ��ϢԴ�Ͷ����߽���ϡ�����UIֻ��Ҫ�����Լ��ĸ����¼���
��service��ֻ��Ҫ���߷ַ����ҷ�������Ϣ��
]]--
local Dispatcher = class("Dispatcher")
function Dispatcher:ctor()
	self._eventDispatcher = {}
end
-------------------------------------------
--����ĳ���¼��ĳ�פ����,�ü��������Զ�ɾ��,�����ڳ�����
--@param event_name �¼�����
--@param func ��������
--@return listener ������
-------------------------------------------
function Dispatcher:addEventListener(event_name,func)
    local listener = { e=event_name , f=func }
	self._eventDispatcher[listener] = false 
    return listener
end

-------------------------------------------
--��ȫ�Ķ���ĳ���¼��ĳ�פ����,���һ�����ȫ���,��ֹ��ͬ�ļ������,�ü��������Զ�ɾ��,�����ڳ�����
--@param event_name �¼�����
--@param func ��������
--@return listener ������
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
--����ĳ���¼����Զ�����,���ּ������յ�һ�κ���Զ����Լ�ɾ��,������һ���Լ���
--@param event_name �¼�����
--@param func ��������
-------------------------------------------
function Dispatcher:addAutoEventListener(event_name,func)
    local listener = { e=event_name , f=func}  
    self._eventDispatcher[listener] = true 
end

-------------------------------------------
--����ĳ���¼�
--@param event_name �¼�����o(n)
--@param ... �����¼������Ĳ���
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
--���¼��ַ�����ɾ��������o(1)
--@param listener ������
-------------------------------------------
function Dispatcher:removeEventListener(listener)
    self._eventDispatcher[listener] = nil 
end

----------------------------------------------------------
--[[
�¼����гأ�����hash�㷨
MAX_DISPATCHER ��ʾ��ǰ���¼�����������
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
--����ĳ���¼��ĳ�פ����,�ü��������Զ�ɾ��,�����ڳ�����
--@param event_name �¼�����
--@param func ��������
--@return listener ������
-------------------------------------------
function DispatcherUtils.addEventListener(event_name,func)
	return getDispatcherByEvent(event_name):addEventListener(event_name,func)
end

-------------------------------------------
--��ȫ�Ķ���ĳ���¼��ĳ�פ����,���һ�����ȫ���,��ֹ��ͬ�ļ������,�ü��������Զ�ɾ��,�����ڳ�����
--@param event_name �¼�����
--@param func ��������
--@return listener ������
-------------------------------------------
function DispatcherUtils.addEventListenerSafe(event_name,func)
	return getDispatcherByEvent(event_name):addEventListenerSafe(event_name,func)
end

-------------------------------------------
--����ĳ���¼����Զ�����,���ּ������յ�һ�κ���Զ����Լ�ɾ��,������һ���Լ���
--@param event_name �¼�����
--@param func ��������
-------------------------------------------
function DispatcherUtils.addAutoEventListener(event_name,func)
    getDispatcherByEvent(event_name):addAutoEventListener(event_name,func)
end

-------------------------------------------
--����ĳ���¼�
--@param event_name �¼�����
--@param ... �����¼������Ĳ���
-------------------------------------------
function DispatcherUtils.dispatchEvent(event_name,...)
    getDispatcherByEvent(event_name):dispatchEvent(event_name,...) 
end

-------------------------------------------
--���¼��ַ�����ɾ��������
--@param listener ������
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