local component = require("component")
local event = require("event")

local metter = component.energy_meter
local powerStatus = true
local reactorStatus = {}

local optTemp = {}
optTemp["hydrogenhydrogen"] = 4430000000
optTemp["hydrogendeuterium"] = 1245000000
optTemp["hydrogenhelium3"] = 3339000000

function optimalTemperature(reactor)
    local first = reactor.getFirstFusionFuel()
    local second = reactor.getSecondFusionFuel()

    if optTemp[first..second] then
        return optTemp[first..second]
    end

    return 0
end

function onPowerFault()
    if powerStatus then
        print("========== ERROR POWER FAULT DETECTED ========== ")
        metter.setTransferRateLimit(0)
        powerStatus = false
    end
end

function onPowerResume()
    if not powerStatus then
        print("========== POWER RESUMED ========== ")
        metter.setTransferRateLimit(-1)
        powerStatus = true
    end
end

function onError()
    print("========== ERROR EXCEPTION ========== ")
end

function checkReactors()
    for address, _ in component.list("nc_fusion_reactor") do
        local reactor = component.proxy(address)

        if reactor.getTemperature() < optimalTemperature(reactor) then
            reactor.activate()
            if not reactorStatus[address] or reactorStatus[address] == nil then
                local first = reactor.getFirstFusionFuel()
                local second = reactor.getSecondFusionFuel()
                print("UP - "..first.." | "..second.." - "..address)
            end
            reactorStatus[address] = true
        else
            reactor.deactivate()
            if reactorStatus[address]  or reactorStatus[address] == nil then
                local first = reactor.getFirstFusionFuel()
                local second = reactor.getSecondFusionFuel()
                print("DOWN - "..first.." | "..second.." - "..address)
            end
            reactorStatus[address] = false
        end
    end
end

function checkPower()
    local allAbove = true

    for address, _ in component.list("nc_fusion_reactor") do
        local reactor = component.proxy(address)
        local ratio = reactor.getEnergyStored() / reactor.getMaxEnergyStored()

        if ratio < 0.5 then
            onPowerFault()
            return
        end

        if ratio < 0.9 then
            allAbove = false
        end
    end
    
    if allAbove then
        onPowerResume()
    end
end

function run()
    fine, error = pcall(checkPower)
    if not fine then
        print(error)
        onPowerFault()
    end

    fine, error = pcall(checkReactors)
    if not fine then
        print(error)
        onError()
    end
end

--SET INITIAL VALUES
metter.setTransferRateLimit(-1)
powerStatus = false

repeat
    fine, error = pcall(checkReactors)
    if not fine then
        print(error)
        onError()
    end
until event.pull(0.1) == "interrupted"

metter.setTransferRateLimit(0)
