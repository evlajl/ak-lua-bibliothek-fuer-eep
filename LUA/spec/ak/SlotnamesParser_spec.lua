describe("AkSlotNamesParser.lua", function()
    describe("getSlotNamesFunction", function()
        describe(".getSlotNames()", function()
            insulate("Slot 1", function()
                require("ak.eep.AkEepFunktionen")
                local _, SlotMapping, SlotFuncs = require('SlotNames_BH2')()
                SlotMapping.Slot1 = 34
                --SlotMapping.Liste = { 36, 37, 38 }
                SlotMapping.Zaehler1 = 1
                SlotMapping.Zaehler2 = 2
                SlotMapping.Zaehler3 = 3
                SlotMapping.Bahnhof = {
                    West = 100,
                    Ost = { a = 101, b = 102 },
                    Sued = 104,
                }
                --SlotMapping.Gleis = { 201, 202, 203, 204 }

                SlotFuncs.checkMapping()
                local p = require("ak.data.AkSlotNamesParser")
                local slotName = p.getSlotName(34)
                it("slotname 34 müsste Slot1 sein", function()
                    assert.is_true(slotName == "Slot1")
                end)
            end)
        end)
    end)
end)
