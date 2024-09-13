local component = require("component")
local event = require("event")

local lowerReactorTemperature = 1156000000
local upperReactorTemperature = 4430000000

local lowerReactorAddress = "ae2938f7-9f56-4b42-8730-9f96ec361e0f"
local upperReactorAddress = "b52aef7d-7339-465c-b986-43d5299d101f"
local batteryMeterAddress = "254e4379-f940-4d25-aecc-6103bb6d75ab"
local gridMetterAddress = "62931ca1-755a-4413-8ed8-da763abc7b35"

local lowerReactor = component.proxy(lowerReactorAddress)
local upperReactor = component.proxy(upperReactorAddress)
local batteryMeter = component.proxy(batteryMeterAddress)
local gridMetter = component.proxy(gridMetterAddress)
local powerStatus = true
local lowerReactorActive = false
local upperReactorActive = false

function onUnknownReactor()
    print("========== ERROR UNKNOWN REACTOR FOUND ========== ")
    local reactors = {}
    for address, reactor in component.list("nc_fusion_reactor") do
        reactor.deactivate()
    end
    os.exit()
end

function onPowerFault()
    if powerStatus then
        print("========== ERROR POWER FAULT DETECTED ========== ")
        gridMetter.setTransferRateLimit(0)
        batteryMeter.setTransferRateLimit(-1)
        powerStatus = false
    end
end

function onPowerResume()
    if not powerStatus then
        print("========== POWER RESUMED ========== ")
        gridMetter.setTransferRateLimit(-1)
        batteryMeter.setTransferRateLimit(0)
        powerStatus = true
    end
end

function onError()
    print("========== ERROR EXCEPTION ========== ")
end

function checkReactors()
    local reactors = {}
    for address, reactor in component.list("nc_fusion_reactor") do
        if not address == lowerReactor and not address == upperReactor then
            onUnknownReactor()
        end
    end

    if upperReactor.getTemperature() >= upperReactorTemperature and upperReactorActive then
        upperReactor.deactivate()
        upperReactorActive = false
        print("UPPER DOWN")
    elseif not upperReactorActive then
        upperReactor.activate()
        upperReactorActive = true
        print("UPPER UP")
    end

    if lowerReactor.getTemperature() >= lowerReactorTemperature and lowerReactorActive then
        lowerReactor.deactivate()
        lowerReactorActive = false
        print("LOWER DOWN")
    elseif not lowerReactorActive then
        lowerReactor.activate()
        lowerReactorActive = true
        print("LOWER UP")
    end
end

function checkPower()
    local lowerReactorPower = lowerReactor.getEnergyStored() / lowerReactor.getMaxEnergyStored()
    local upperReactorPower = upperReactor.getEnergyStored() / upperReactor.getMaxEnergyStored()

    if lowerReactorPower < 0.5 or upperReactorPower < 0.5 then
        onPowerFault()
    elseif lowerReactorPower > 0.95 and upperReactorPower > 0.95 then
        onPowerResume()
    end
end

function run()
    if not pcall(checkPower) then
        onPowerFault()
    end

    if not pcall(checkReactors) then
        onError()
    end
end

--SET INITIAL VALUES
lowerReactor.deactivate()
upperReactor.deactivate()
lowerReactorActive = false
upperReactorActive = false
gridMetter.setTransferRateLimit(-1)
batteryMeter.setTransferRateLimit(0)
powerStatus = false

repeat
    if not pcall(run) then
        onError()
    end
until event.pull(0.1) == "interrupted"

gridMetter.setTransferRateLimit(0)
batteryMeter.setTransferRateLimit(-1)
lowerReactor.deactivate()
upperReactor.deactivate()
