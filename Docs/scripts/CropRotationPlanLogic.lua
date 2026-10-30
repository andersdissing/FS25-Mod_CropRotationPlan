-- CropRotationPlanLogic.lua
-- Pure functions: no game API calls, so the logic can be tested outside the game.

CropRotationPlanLogic = {}

-- Game period 1 = March ... period 10 = December, 11 = January, 12 = February.
function CropRotationPlanLogic.periodToMonth(period)
    return ((period + 1) % 12) + 1
end

function CropRotationPlanLogic.monthToPeriod(month)
    return ((month - 3) % 12) + 1
end

-- Returns the cycle year (1..cycleLength) or nil if the plan hasn't started yet.
function CropRotationPlanLogic.getCycleYear(cycleLength, currentYear, startYear)
    if currentYear < startYear then
        return nil
    end
    return ((currentYear - startYear) % cycleLength) + 1
end

local function taskFirstPeriod(task)
    local first = nil
    for _, m in ipairs(task.months) do
        local p = CropRotationPlanLogic.monthToPeriod(m)
        if first == nil or p < first then
            first = p
        end
    end
    return first
end

local function taskIsInPeriod(task, period)
    for _, m in ipairs(task.months) do
        if CropRotationPlanLogic.monthToPeriod(m) == period then
            return true
        end
    end
    return false
end

-- Tasks sorted by their first month in plan-year order (March first).
local function sortedTasks(tasks)
    local list = {}
    for _, t in ipairs(tasks) do
        table.insert(list, t)
    end
    table.sort(list, function(a, b)
        return taskFirstPeriod(a) < taskFirstPeriod(b)
    end)
    return list
end

-- Status for one field.
-- Returns a table:
--   state       "waiting" (plan starts later), "start" (autumn before year 1), "active"
--   cycleYear   1..cycleLength (active only)
--   cycleLength number of years in the field's cycle
--   phaseLabel  label of this year's phase (active only)
--   yearsToStart years until cycle year 1 (waiting/start only)
--   nowTasks    tasks to do in the current period
--   nextTask    next task after the current period, or nil
--   nextIsNextYear true if nextTask belongs to the next game year
function CropRotationPlanLogic.getFieldStatus(data, field, currentYear, currentPeriod, startYear)
    local status = {
        cycleLength = #field.phases,
        nowTasks = {},
        nextTask = nil,
        nextIsNextYear = false,
    }

    local thisYearTasks
    local nextYearTasks

    local cycleYear = CropRotationPlanLogic.getCycleYear(status.cycleLength, currentYear, startYear)
    if cycleYear == nil then
        status.yearsToStart = startYear - currentYear
        if status.yearsToStart > 1 then
            status.state = "waiting"
            return status
        end
        status.state = "start"
        thisYearTasks = {}
        if field.start ~= nil then
            thisYearTasks = { field.start }
        end
        nextYearTasks = data.PHASES[field.phases[1]].tasks
    else
        status.state = "active"
        status.cycleYear = cycleYear
        local phase = data.PHASES[field.phases[cycleYear]]
        status.phaseLabel = phase.label
        thisYearTasks = phase.tasks
        local nextCycleYear = (cycleYear % status.cycleLength) + 1
        nextYearTasks = data.PHASES[field.phases[nextCycleYear]].tasks
    end

    local sorted = sortedTasks(thisYearTasks)
    for _, task in ipairs(sorted) do
        if taskIsInPeriod(task, currentPeriod) then
            table.insert(status.nowTasks, task)
        elseif status.nextTask == nil and taskFirstPeriod(task) > currentPeriod then
            status.nextTask = task
        end
    end

    if status.nextTask == nil then
        local nextSorted = sortedTasks(nextYearTasks)
        if #nextSorted > 0 then
            status.nextTask = nextSorted[1]
            status.nextIsNextYear = true
        end
    end

    return status
end
