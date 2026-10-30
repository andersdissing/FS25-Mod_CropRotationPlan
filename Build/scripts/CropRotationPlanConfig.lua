-- CropRotationPlanConfig.lua
-- Reads the crop rotation plan from XML and compiles it into the structure
-- the logic and drawing code use:
--
--   data.PHASES[key] = { label, tasks = { { months, action, crop } } }
--   data.GROUPS      = { { title, cycleLength, fields = { { name, phases = {key..}, start } } } }
--
-- User file:    <profile>/modSettings/FS25_CropRotationPlan/cropRotationPlan.xml
-- Default file: <mod>/defaultConfig.xml (written to the user file if that is missing)

CropRotationPlanConfig = {}
CropRotationPlanConfig.ROOT = "cropRotationPlanConfig"
CropRotationPlanConfig.FOLDER = "modSettings/FS25_CropRotationPlan/"
CropRotationPlanConfig.FILENAME = "cropRotationPlan.xml"

local ROOT = CropRotationPlanConfig.ROOT

---------------------------------------------------------------------------
-- Parsing helpers
---------------------------------------------------------------------------

-- "8 9" / "4-7" / "11-2" / "6,7" -> { 8, 9 } ... ; nil + error text on bad input
function CropRotationPlanConfig.parseMonths(text)
    if text == nil then
        return nil, nil
    end
    local months = {}
    local seen = {}
    local function add(m)
        if not seen[m] then
            seen[m] = true
            table.insert(months, m)
        end
    end
    for token in string.gmatch(text, "[^%s,]+") do
        local a, b = string.match(token, "^(%d+)%-(%d+)$")
        if a ~= nil then
            a, b = tonumber(a), tonumber(b)
            if a < 1 or a > 12 or b < 1 or b > 12 then
                return nil, "month out of range in '" .. text .. "'"
            end
            local m = a
            while true do
                add(m)
                if m == b then
                    break
                end
                m = (m % 12) + 1
            end
        else
            local n = tonumber(token)
            if n == nil or n < 1 or n > 12 or n ~= math.floor(n) then
                return nil, "invalid month '" .. token .. "' in '" .. text .. "'"
            end
            add(n)
        end
    end
    if #months == 0 then
        return nil, "no months in '" .. text .. "'"
    end
    return months, nil
end

local function splitNumbers(text)
    local list = {}
    if text ~= nil then
        for token in string.gmatch(text, "[^%s,]+") do
            table.insert(list, token)
        end
    end
    return list
end

---------------------------------------------------------------------------
-- XML -> raw config table (strings kept as written, so it can be written back)
---------------------------------------------------------------------------

function CropRotationPlanConfig.read(xmlFile)
    local config = { crops = {}, plans = {}, fieldGroups = {} }

    local i = 0
    while true do
        local key = string.format("%s.crops.crop(%d)", ROOT, i)
        if not xmlFile:hasProperty(key) then
            break
        end
        table.insert(config.crops, {
            name = xmlFile:getString(key .. "#name"),
            sow = xmlFile:getString(key .. "#sow"),
            harvest = xmlFile:getString(key .. "#harvest"),
        })
        i = i + 1
    end

    local p = 0
    while true do
        local planKey = string.format("%s.plans.plan(%d)", ROOT, p)
        if not xmlFile:hasProperty(planKey) then
            break
        end
        local plan = {
            name = xmlFile:getString(planKey .. "#name"),
            years = xmlFile:getInt(planKey .. "#years"),
            yearList = {},
        }
        local y = 0
        while true do
            local yearKey = string.format("%s.year(%d)", planKey, y)
            if not xmlFile:hasProperty(yearKey) then
                break
            end
            local entries = {}
            local c = 0
            while true do
                local cropKey = string.format("%s.crop(%d)", yearKey, c)
                if not xmlFile:hasProperty(cropKey) then
                    break
                end
                table.insert(entries, {
                    name = xmlFile:getString(cropKey .. "#name"),
                    sow = xmlFile:getString(cropKey .. "#sow"),
                    harvest = xmlFile:getString(cropKey .. "#harvest"),
                })
                c = c + 1
            end
            table.insert(plan.yearList, entries)
            y = y + 1
        end
        table.insert(config.plans, plan)
        p = p + 1
    end

    local g = 0
    while true do
        local key = string.format("%s.fieldGroups.fieldGroup(%d)", ROOT, g)
        if not xmlFile:hasProperty(key) then
            break
        end
        table.insert(config.fieldGroups, {
            fields = xmlFile:getString(key .. "#fields"),
            plan = xmlFile:getString(key .. "#plan"),
            startPlanYear = xmlFile:getInt(key .. "#startPlanYear"),
        })
        g = g + 1
    end

    return config
end

local function setIfNotNil(xmlFile, key, value)
    if value ~= nil then
        xmlFile:setString(key, value)
    end
end

function CropRotationPlanConfig.write(path, config)
    local xmlFile = XMLFile.create("cropRotationPlanConfigXML", path, ROOT)
    if xmlFile == nil then
        return false
    end
    xmlFile:setInt(ROOT .. "#version", 1)
    for i, crop in ipairs(config.crops) do
        local key = string.format("%s.crops.crop(%d)", ROOT, i - 1)
        setIfNotNil(xmlFile, key .. "#name", crop.name)
        setIfNotNil(xmlFile, key .. "#sow", crop.sow)
        setIfNotNil(xmlFile, key .. "#harvest", crop.harvest)
    end
    for p, plan in ipairs(config.plans) do
        local planKey = string.format("%s.plans.plan(%d)", ROOT, p - 1)
        setIfNotNil(xmlFile, planKey .. "#name", plan.name)
        if plan.years ~= nil then
            xmlFile:setInt(planKey .. "#years", plan.years)
        end
        for y, entries in ipairs(plan.yearList) do
            for c, entry in ipairs(entries) do
                local cropKey = string.format("%s.year(%d).crop(%d)", planKey, y - 1, c - 1)
                setIfNotNil(xmlFile, cropKey .. "#name", entry.name)
                setIfNotNil(xmlFile, cropKey .. "#sow", entry.sow)
                setIfNotNil(xmlFile, cropKey .. "#harvest", entry.harvest)
            end
        end
    end
    for g, group in ipairs(config.fieldGroups) do
        local key = string.format("%s.fieldGroups.fieldGroup(%d)", ROOT, g - 1)
        setIfNotNil(xmlFile, key .. "#fields", group.fields)
        setIfNotNil(xmlFile, key .. "#plan", group.plan)
        if group.startPlanYear ~= nil then
            xmlFile:setInt(key .. "#startPlanYear", group.startPlanYear)
        end
    end
    xmlFile:save()
    xmlFile:delete()
    return true
end

---------------------------------------------------------------------------
-- Raw config -> compiled data. Returns data, errors, warnings (lists of strings).
-- Errors make the loader fall back to the default plan, warnings are only logged.
---------------------------------------------------------------------------

function CropRotationPlanConfig.compile(config)
    local errors = {}
    local warnings = {}
    local function err(fmt, ...)
        table.insert(errors, string.format(fmt, ...))
    end
    local function warn(fmt, ...)
        table.insert(warnings, string.format(fmt, ...))
    end

    -- Crop calendar
    local calendar = {}
    for _, crop in ipairs(config.crops) do
        if crop.name == nil then
            err("crop without name in <crops>")
        else
            local entry = {}
            local e
            entry.sow, e = CropRotationPlanConfig.parseMonths(crop.sow)
            if e ~= nil then err("crop %s sow: %s", crop.name, e) end
            entry.harvest, e = CropRotationPlanConfig.parseMonths(crop.harvest)
            if e ~= nil then err("crop %s harvest: %s", crop.name, e) end
            calendar[string.lower(crop.name)] = entry
        end
    end

    local function months(entry, field, planName, yearIndex)
        local own, e = CropRotationPlanConfig.parseMonths(entry[field])
        if e ~= nil then
            err("plan '%s' year %d %s %s: %s", planName, yearIndex, entry.name, field, e)
            return nil
        end
        if own ~= nil then
            return own
        end
        local cal = calendar[string.lower(entry.name)]
        if cal ~= nil and cal[field] ~= nil then
            return cal[field]
        end
        err("plan '%s' year %d: no %s months for %s (add it to <crops> or set %s=\"..\")", planName, yearIndex, field, entry.name, field)
        return nil
    end

    local data = { PHASES = {}, GROUPS = {} }
    local plansByName = {}

    for p, plan in ipairs(config.plans) do
        local name = plan.name or ("plan " .. p)
        local L = #plan.yearList
        local valid = true

        if plan.years ~= nil and plan.years ~= L then
            err("plan '%s': years=\"%d\" but it has %d <year> elements", name, plan.years, L)
            valid = false
        end
        if L == 0 then
            err("plan '%s' has no <year>", name)
            valid = false
        end
        for y, entries in ipairs(plan.yearList) do
            if #entries == 0 then
                err("plan '%s' year %d has no crops", name, y)
                valid = false
            end
            for _, entry in ipairs(entries) do
                if entry.name == nil then
                    err("plan '%s' year %d: crop without name", name, y)
                    valid = false
                end
            end
        end

        if valid then
            local compiled = { name = name, cycleLength = L, phaseKeys = {}, startTasks = {} }
            for y = 1, L do
                local entries = plan.yearList[y]
                local prevEntries = plan.yearList[((y - 2) % L) + 1]
                local nextEntries = plan.yearList[(y % L) + 1]
                local prevLast = prevEntries[#prevEntries]
                local nextFirst = nextEntries[1]

                local tasks = {}
                local labels = {}
                for i, entry in ipairs(entries) do
                    table.insert(labels, entry.name)
                    local carriedIn = (i == 1) and string.lower(prevLast.name) == string.lower(entry.name)
                    local carriedOut = (i == #entries) and string.lower(nextFirst.name) == string.lower(entry.name)
                    local single = (#entries == 1)

                    local needSow = (not carriedIn) or (single and carriedIn and carriedOut)
                    local needHarvest = (not carriedOut) or (single and carriedIn and carriedOut)

                    -- Months written where they are not used (the event happens in the other year)
                    if entry.sow ~= nil and not needSow and not carriedOut then
                        warn("plan '%s' year %d: sow=\"%s\" on %s is ignored, it is sown the year before (put it on the last %s in year %d)",
                            name, y, entry.sow, entry.name, entry.name, ((y - 2) % L) + 1)
                    end
                    if entry.harvest ~= nil and not needHarvest then
                        warn("plan '%s' year %d: harvest=\"%s\" on %s is ignored, it is harvested the year after (put it on the first %s in year %d)",
                            name, y, entry.harvest, entry.name, entry.name, (y % L) + 1)
                    end

                    if needHarvest and not needSow and carriedIn then
                        -- Harvest of a crop sown last autumn
                        local h = months(entry, "harvest", name, y)
                        if h ~= nil then table.insert(tasks, { months = h, action = "harvest", crop = entry.name }) end
                    else
                        if needSow then
                            local s = months(entry, "sow", name, y)
                            if s ~= nil then table.insert(tasks, { months = s, action = "sow", crop = entry.name }) end
                        end
                        if needHarvest then
                            local h = months(entry, "harvest", name, y)
                            if h ~= nil then table.insert(tasks, { months = h, action = "harvest", crop = entry.name }) end
                        end
                    end

                    -- Autumn work before cycle year 1 when the group starts in plan year y+1
                    if carriedOut then
                        local s = months(entry, "sow", name, y)
                        if s ~= nil then
                            compiled.startTasks[(y % L) + 1] = { months = s, action = "sow", crop = entry.name }
                        end
                    end
                end

                local key = p .. "_" .. y
                data.PHASES[key] = { label = table.concat(labels, " -> "), tasks = tasks }
                compiled.phaseKeys[y] = key
            end
            plansByName[name] = compiled
        end
    end

    -- Field groups, collected per plan in plan order
    local groupByPlan = {}
    for g, fg in ipairs(config.fieldGroups) do
        local plan = fg.plan ~= nil and plansByName[fg.plan] or nil
        local numbers = splitNumbers(fg.fields)
        if #numbers == 0 then
            err("fieldGroup %d: no fields", g)
        elseif plan == nil then
            err("fieldGroup '%s': unknown plan '%s'", tostring(fg.fields), tostring(fg.plan))
        else
            local L = plan.cycleLength
            local sp = fg.startPlanYear or 1
            if sp < 1 or sp > L then
                err("fieldGroup '%s': startPlanYear %d is outside 1..%d", fg.fields, sp, L)
            else
                local phases = {}
                for n = 1, L do
                    phases[n] = plan.phaseKeys[((sp - 1 + n - 1) % L) + 1]
                end
                local field = {
                    name = table.concat(numbers, ", "),
                    phases = phases,
                    start = plan.startTasks[sp],
                }
                if groupByPlan[plan.name] == nil then
                    groupByPlan[plan.name] = { title = plan.name, cycleLength = L, fields = {} }
                end
                table.insert(groupByPlan[plan.name].fields, field)
            end
        end
    end
    for _, plan in ipairs(config.plans) do
        local group = plan.name ~= nil and groupByPlan[plan.name] or nil
        if group ~= nil then
            table.insert(data.GROUPS, group)
        end
    end
    if #data.GROUPS == 0 then
        err("no field groups with a valid plan")
    end

    return data, errors, warnings
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

function CropRotationPlanConfig.getUserPath()
    return getUserProfileAppPath() .. CropRotationPlanConfig.FOLDER .. CropRotationPlanConfig.FILENAME
end

local function loadFile(path)
    if not fileExists(path) then
        return nil
    end
    local xmlFile = XMLFile.load("cropRotationPlanConfigXML", path)
    if xmlFile == nil then
        return nil
    end
    local config = CropRotationPlanConfig.read(xmlFile)
    xmlFile:delete()
    return config
end

-- Returns data, errors, usedDefault
function CropRotationPlanConfig.load(modDirectory)
    local defaultPath = modDirectory .. "defaultConfig.xml"
    local defaultConfig = loadFile(defaultPath)

    local userPath = CropRotationPlanConfig.getUserPath()
    if not fileExists(userPath) and defaultConfig ~= nil then
        createFolder(getUserProfileAppPath() .. "modSettings/")
        createFolder(getUserProfileAppPath() .. CropRotationPlanConfig.FOLDER)
        CropRotationPlanConfig.write(userPath, defaultConfig)
    end

    local userConfig = loadFile(userPath)
    local errors = {}
    if userConfig ~= nil then
        local data, userErrors, userWarnings = CropRotationPlanConfig.compile(userConfig)
        for _, w in ipairs(userWarnings) do
            Logging.warning("[CropRotationPlan] %s", w)
        end
        if #userErrors == 0 then
            return data, {}, false
        end
        errors = userErrors
    else
        table.insert(errors, "could not read " .. userPath)
    end

    if defaultConfig ~= nil then
        local data = CropRotationPlanConfig.compile(defaultConfig)
        return data, errors, true
    end
    table.insert(errors, "could not read " .. defaultPath)
    return { PHASES = {}, GROUPS = {} }, errors, true
end
