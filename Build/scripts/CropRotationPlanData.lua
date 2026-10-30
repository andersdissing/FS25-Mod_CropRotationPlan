-- CropRotationPlanData.lua
-- Plans, field groups and settings, stored per savegame in <savegame>/cropRotationPlan.xml.
-- A new savegame starts with no plans and no field groups.
--
--   <cropRotationPlan version="2">
--     <settings displayMode="full" position="top" grassInRotation="true"/>
--     <plans>
--       <plan id="1" name="4-year rotation" years="4">
--         <seed crop="WHEAT" t="9"/>
--         <seed crop="GRASS" t="3" dur="12" cut="2"/>
--       </plan>
--     </plans>
--     <fieldGroups>
--       <fieldGroup fields="3 4 5" plan="1" planYear="2" anchorYear="5"/>
--     </fieldGroups>
--   </cropRotationPlan>
--
-- Files written by v1.x only have <settings>; their startYear is ignored (field groups
-- now carry their own "plan year now").

CropRotationPlanData = {}
CropRotationPlanData.FILENAME = "cropRotationPlan.xml"
CropRotationPlanData.XML_ROOT = "cropRotationPlan"
CropRotationPlanData.VERSION = 2

CropRotationPlanData.DISPLAY_MODES = { "full", "minimized", "hidden" }
CropRotationPlanData.POSITIONS = { "top", "left" }

function CropRotationPlanData.new()
    return {
        settings = {
            displayMode = "full",
            position = "top",
            grassInRotation = true,
        },
        plans = {},
        groups = {},
        nextPlanId = 1,
    }
end

local function getPath()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end
    local dir = g_currentMission.missionInfo.savegameDirectory
    if dir == nil then
        return nil
    end
    return dir .. "/" .. CropRotationPlanData.FILENAME
end
CropRotationPlanData.getPath = getPath

local function parseIds(text)
    local ids = {}
    for part in string.gmatch(text or "", "%S+") do
        local id = tonumber(part)
        if id ~= nil then
            table.insert(ids, math.floor(id))
        end
    end
    return ids
end

local function joinIds(ids)
    local parts = {}
    for _, id in ipairs(ids) do
        table.insert(parts, tostring(id))
    end
    return table.concat(parts, " ")
end

local function isOneOf(value, list)
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

function CropRotationPlanData.load()
    local data = CropRotationPlanData.new()
    local path = getPath()
    if path == nil or not fileExists(path) then
        return data
    end
    local xmlFile = XMLFile.load("cropRotationPlanXML", path)
    if xmlFile == nil then
        return data
    end
    local root = CropRotationPlanData.XML_ROOT

    local s = data.settings
    local mode = xmlFile:getString(root .. ".settings#displayMode")
    if mode == nil then
        -- Files from version 1.0 only have hudVisible
        mode = xmlFile:getBool(root .. ".settings#hudVisible", true) and "full" or "hidden"
    end
    if isOneOf(mode, CropRotationPlanData.DISPLAY_MODES) then
        s.displayMode = mode
    end
    local position = xmlFile:getString(root .. ".settings#position")
    if isOneOf(position, CropRotationPlanData.POSITIONS) then
        s.position = position
    end
    s.grassInRotation = xmlFile:getBool(root .. ".settings#grassInRotation", true)

    local i = 0
    while true do
        local key = string.format("%s.plans.plan(%d)", root, i)
        if not xmlFile:hasProperty(key) then
            break
        end
        local plan = {
            id = xmlFile:getInt(key .. "#id", data.nextPlanId),
            name = xmlFile:getString(key .. "#name", ""),
            years = math.max(1, math.min(CropRotationPlanLogic.MAX_YEARS, xmlFile:getInt(key .. "#years", 1))),
            seeds = {},
        }
        local Lm = plan.years * 12
        local j = 0
        while true do
            local seedKey = string.format("%s.seed(%d)", key, j)
            if not xmlFile:hasProperty(seedKey) then
                break
            end
            local crop = xmlFile:getString(seedKey .. "#crop")
            local t = xmlFile:getInt(seedKey .. "#t")
            if crop ~= nil and t ~= nil then
                table.insert(plan.seeds, {
                    crop = crop,
                    t = t % Lm,
                    dur = xmlFile:getInt(seedKey .. "#dur"),
                    cut = xmlFile:getInt(seedKey .. "#cut"),
                })
            end
            j = j + 1
        end
        table.insert(data.plans, plan)
        data.nextPlanId = math.max(data.nextPlanId, plan.id + 1)
        i = i + 1
    end

    i = 0
    while true do
        local key = string.format("%s.fieldGroups.fieldGroup(%d)", root, i)
        if not xmlFile:hasProperty(key) then
            break
        end
        table.insert(data.groups, {
            fields = parseIds(xmlFile:getString(key .. "#fields", "")),
            planId = xmlFile:getInt(key .. "#plan"),
            planYear = xmlFile:getInt(key .. "#planYear", 1),
            anchorYear = xmlFile:getInt(key .. "#anchorYear"),
        })
        i = i + 1
    end

    xmlFile:delete()
    Logging.info("[CropRotationPlan] Loaded %d plans and %d field groups from %s", #data.plans, #data.groups, path)
    return data
end

-- Writes the file. Before a new career is saved the first time there is no savegame folder;
-- then the data stays in memory and is written by the save hook in CropRotationPlan.lua.
function CropRotationPlanData.save(data)
    local path = getPath()
    if path == nil then
        return false
    end
    local root = CropRotationPlanData.XML_ROOT
    local xmlFile = XMLFile.create("cropRotationPlanXML", path, root)
    if xmlFile == nil then
        return false
    end
    xmlFile:setInt(root .. "#version", CropRotationPlanData.VERSION)

    local s = data.settings
    xmlFile:setString(root .. ".settings#displayMode", s.displayMode)
    xmlFile:setString(root .. ".settings#position", s.position)
    xmlFile:setBool(root .. ".settings#grassInRotation", s.grassInRotation)

    for i, plan in ipairs(data.plans) do
        local key = string.format("%s.plans.plan(%d)", root, i - 1)
        xmlFile:setInt(key .. "#id", plan.id)
        xmlFile:setString(key .. "#name", plan.name)
        xmlFile:setInt(key .. "#years", plan.years)
        for j, seed in ipairs(plan.seeds) do
            local seedKey = string.format("%s.seed(%d)", key, j - 1)
            xmlFile:setString(seedKey .. "#crop", seed.crop)
            xmlFile:setInt(seedKey .. "#t", seed.t)
            if seed.dur ~= nil then
                xmlFile:setInt(seedKey .. "#dur", seed.dur)
            end
            if seed.cut ~= nil then
                xmlFile:setInt(seedKey .. "#cut", seed.cut)
            end
        end
    end

    for i, group in ipairs(data.groups) do
        local key = string.format("%s.fieldGroups.fieldGroup(%d)", root, i - 1)
        xmlFile:setString(key .. "#fields", joinIds(group.fields))
        if group.planId ~= nil then
            xmlFile:setInt(key .. "#plan", group.planId)
        end
        xmlFile:setInt(key .. "#planYear", group.planYear or 1)
        if group.anchorYear ~= nil then
            xmlFile:setInt(key .. "#anchorYear", group.anchorYear)
        end
    end

    xmlFile:save()
    xmlFile:delete()
    return true
end

---------------------------------------------------------------------------
-- Editing helpers (pure table operations)
---------------------------------------------------------------------------

function CropRotationPlanData.getPlan(data, id)
    for _, plan in ipairs(data.plans) do
        if plan.id == id then
            return plan
        end
    end
    return nil
end

function CropRotationPlanData.copyPlan(plan)
    local copy = { id = plan.id, name = plan.name, years = plan.years, seeds = {} }
    for _, seed in ipairs(plan.seeds) do
        table.insert(copy.seeds, { crop = seed.crop, t = seed.t, dur = seed.dur, cut = seed.cut })
    end
    return copy
end

function CropRotationPlanData.addPlan(data, name)
    local plan = { id = data.nextPlanId, name = name, years = 4, seeds = {} }
    data.nextPlanId = data.nextPlanId + 1
    table.insert(data.plans, plan)
    return plan
end

-- Replaces the stored plan with the edited copy (Save in the plan editor)
function CropRotationPlanData.putPlan(data, edited)
    for i, plan in ipairs(data.plans) do
        if plan.id == edited.id then
            data.plans[i] = CropRotationPlanData.copyPlan(edited)
            return
        end
    end
    table.insert(data.plans, CropRotationPlanData.copyPlan(edited))
end

-- Removes the plan; field groups that used it keep their fields but have no plan
function CropRotationPlanData.removePlan(data, id)
    for i, plan in ipairs(data.plans) do
        if plan.id == id then
            table.remove(data.plans, i)
            break
        end
    end
    for _, group in ipairs(data.groups) do
        if group.planId == id then
            group.planId = nil
        end
    end
end

function CropRotationPlanData.countGroupsForPlan(data, id)
    local n = 0
    for _, group in ipairs(data.groups) do
        if group.planId == id then
            n = n + 1
        end
    end
    return n
end

function CropRotationPlanData.addGroup(data, calendarYear)
    local group = { fields = {}, planId = nil, planYear = 1, anchorYear = calendarYear }
    if #data.plans > 0 then
        group.planId = data.plans[1].id
    end
    table.insert(data.groups, group)
    return group
end

function CropRotationPlanData.removeGroup(data, index)
    table.remove(data.groups, index)
end

-- Group that has the field, or nil
function CropRotationPlanData.getGroupOfField(data, fieldId)
    for i, group in ipairs(data.groups) do
        for _, id in ipairs(group.fields) do
            if id == fieldId then
                return group, i
            end
        end
    end
    return nil
end

-- Adds the field to the group (and takes it out of any other group)
function CropRotationPlanData.addFieldToGroup(data, group, fieldId)
    CropRotationPlanData.removeField(data, fieldId)
    table.insert(group.fields, fieldId)
    table.sort(group.fields)
end

function CropRotationPlanData.removeField(data, fieldId)
    for _, group in ipairs(data.groups) do
        for i = #group.fields, 1, -1 do
            if group.fields[i] == fieldId then
                table.remove(group.fields, i)
            end
        end
    end
end

-- Example: the owner's Riverbend Springs plan from the mockups (console crpLoadExample)
function CropRotationPlanData.loadExample(data, calendarYear)
    data.plans = {}
    data.groups = {}
    data.nextPlanId = 1
    local four = CropRotationPlanData.addPlan(data, "4-year rotation")
    four.years = 4
    four.seeds = {
        { crop = "CARROT", t = 5 }, { crop = "WHEAT", t = 9 }, { crop = "CANOLA", t = 19 },
        { crop = "CARROT", t = 30 }, { crop = "PEA", t = 38 }, { crop = "BARLEY", t = 44 },
    }
    local two = CropRotationPlanData.addPlan(data, "2-year canola")
    two.years = 2
    two.seeds = { { crop = "CANOLA", t = 19 }, { crop = "CARROT", t = 6 }, { crop = "PEA", t = 14 } }
    local groups = {
        { "3 4 5", four, 1 }, { "6 7", four, 2 }, { "8", four, 4 }, { "23 25", four, 3 },
        { "76", two, 1 }, { "77", two, 2 },
    }
    for _, g in ipairs(groups) do
        table.insert(data.groups, { fields = parseIds(g[1]), planId = g[2].id, planYear = g[3], anchorYear = calendarYear })
    end
end
