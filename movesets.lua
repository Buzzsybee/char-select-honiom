if not _G.charSelectExists then return end

gExtrasStates = {}
function reset_hmario_states(index)
    if index == nil then index = 0 end
    gExtrasStates[index] = {
        index = network_global_index_from_local(0),
        actionTick = 0,
        prevFrameAction = 0,
        jumpNumber = 0,
        cancapthrow = true,
        capThrowtimer = 0,
        lastSpeed = 0,
        rollendtimer = 0,
        rollEndTimerOnZ = 0,

        gfxAngleX = 0,
        gfxAngleY = 0,
        gfxAngleZ = 0,
    }
end

for i = 0, (MAX_PLAYERS - 1) do
    reset_hmario_states(i)
end

ACT_CAP_THROW_AIR_H = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING)
ACT_CAP_THROW_GROUND_H = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING)
ACT_ROLL_H = allocate_mario_action(ACT_GROUP_MOVING | ACT_FLAG_MOVING)
ACT_WALL_SLIDE = allocate_mario_action(0x0BF | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_ROLL_BOOST = allocate_mario_action(ACT_FLAG_AIR | ACT_FLAG_MOVING)

local jumpLandActs = {
    ACT_JUMP_LAND,
    ACT_JUMP_LAND_STOP,
    ACT_DOUBLE_JUMP_LAND,
    ACT_DOUBLE_JUMP_LAND_STOP,
    ACT_TRIPLE_JUMP_LAND,
    ACT_TRIPLE_JUMP_LAND_STOP,
    ACT_SIDE_FLIP_LAND,
    ACT_SIDE_FLIP_LAND_STOP,
    ACT_BACKFLIP_LAND,
    ACT_BACKFLIP_LAND_STOP,
    ACT_LONG_JUMP_LAND,
    ACT_LONG_JUMP_LAND_STOP,
    ACT_FREEFALL_LAND_STOP,
    ACT_FREEFALL_LAND,
    ACT_DIVE_SLIDE
}

local jumpLandActsSet = {}
for _, v in ipairs(jumpLandActs) do
    jumpLandActsSet[v] = true
end

local jumpactslist = {
    ACT_JUMP,
    ACT_DOUBLE_JUMP,
    ACT_TRIPLE_JUMP,
    ACT_SIDE_FLIP,
    ACT_BACKFLIP,
    ACT_STEEP_JUMP,
    ACT_WALL_KICK_AIR,
    ACT_LONG_JUMP,
    ACT_FREEFALL,
}

local jumpActs = {}
for _, v in ipairs(jumpactslist) do
    jumpActs[v] = true
end

local bonkActList = {
    ACT_GROUND_BONK,
    ACT_BACKWARD_AIR_KB,
    ACT_BACKWARD_GROUND_KB,
    ACT_HARD_BACKWARD_AIR_KB
}

local bonkActs = {}
for _, v in ipairs(bonkActList) do
    bonkActs[v] = true
end

local groundCapThrowActsList = {
    ACT_WALKING,
    ACT_IDLE,
}

local groundCapThrowActs = {}
for _, v in ipairs(groundCapThrowActsList) do
    groundCapThrowActs[v] = true
end

local function spawn_particle(m, particle)
    m.particleFlags = m.particleFlags | particle
end

local function convert_s16(num)
    local min = -32768
    local max = 32767
    while (num < min) do
        num = max + (num - min)
    end
    while (num > max) do
        num = min + (num - max)
    end
    return num
end

local function set_turn_speed(m, speed)
    m.faceAngle.y = m.intendedYaw - approach_s32(convert_s16(m.intendedYaw - m.faceAngle.y), 0, speed, speed)
end

function get_current_speed(m)
    return math.sqrt((m.vel.x * m.vel.x) + (m.vel.z * m.vel.z))
end

local function update_rolling_speed(m)
    local e = gExtrasStates[m.playerIndex]
    local maxTargetSpeed = 0.0;
    local targetSpeed = 0.0;

    if (m.floor ~= nil and m.floor.type == SURFACE_SLOW) then
        maxTargetSpeed = e.lastSpeed;
    else
        maxTargetSpeed = e.lastSpeed;
    end

    if (m.intendedMag < maxTargetSpeed) then
        targetSpeed = m.intendedMag + 20
    else
        targetSpeed = maxTargetSpeed
    end

    if (m.forwardVel <= 0.0) then
        m.forwardVel = m.forwardVel + 2.1;
    elseif (m.forwardVel <= targetSpeed) then
        m.forwardVel = m.forwardVel + 2.1;
    end

    if m.forwardVel > 70.0 then
        m.forwardVel = 70.0;
    end
    if m.forwardVel > 60 then
        set_turn_speed(m, 0x200)
    else
        set_turn_speed(m, 0x500)
    end

    apply_slope_accel(m);
end

local function allow_cap_throw(m)
    local e = gExtrasStates[m.playerIndex]
    local buttonP = m.controller.buttonPressed
    
    if e.cancapthrow then
        if buttonP & (X_BUTTON | Y_BUTTON) ~= 0 and jumpActs[m.action] then
            set_mario_action(m, ACT_CAP_THROW_AIR_H, 0)
            e.cancapthrow = false
        end
        if buttonP & (X_BUTTON | Y_BUTTON) ~= 0 and groundCapThrowActs[m.action] then
            set_mario_action(m, ACT_CAP_THROW_GROUND_H, 0)
            e.cancapthrow = false
        end
    end
    if not e.cancapthrow then
        e.capThrowtimer = e.capThrowtimer + 1

        if e.capThrowtimer > 25 then
            e.cancapthrow = true
            e.capThrowtimer = 0
        end
    end
end

local function make_actionable(m)
    local e = gExtrasStates[m.playerIndex]
    local mag = (m.controller.stickMag) / 64
    local buttonP = m.controller.buttonPressed
    local buttonD = m.controller.buttonDown

    allow_cap_throw(m)

    -- Jump
    if buttonP & A_BUTTON ~= 0 then
            set_mario_action(m, ACT_JUMP, 0)
        return true
    end

    -- Crouch / slide
    if buttonD & Z_TRIG ~= 0 then
        if mag > 0 then
            set_mario_action(m, ACT_CROUCH_SLIDE, 0)
        else
            set_mario_action(m, ACT_START_CROUCHING, 0)
        end
        return true
    end

    --Start moving (walk/run)
    if mag > 0 and e.actionTick > 1 then
        set_mario_action(m, ACT_WALKING, 0)
        return true
    end
    return true
end

local function make_air_actionable(m)
    local e = gExtrasStates[m.playerIndex]
    local buttonP = m.controller.buttonPressed

    allow_cap_throw(m)

    if buttonP & Z_TRIG ~= 0 then
        set_mario_action(m, ACT_GROUND_POUND, 0)
        return true
    end
end

local function jump_gravity(m)
    if m.action ~= ACT_LONG_JUMP then
        m.vel.y = m.vel.y + 6
    else 
        m.vel.y = m.vel.y - 6
    end
end

local function act_cap_throw_air_h(m)
    local e = gExtrasStates[m.playerIndex]
    
    common_air_action_step(m, ACT_FREEFALL_LAND, CHAR_ANIM_THROW_LIGHT_OBJECT, AIR_STEP_NONE)
    if e.actionTick == 0 then
        play_character_sound(m, CHAR_SOUND_WAH2)
        m.forwardVel = m.forwardVel / 2

        m.marioObj.header.gfx.angle.y = m.faceAngle.y 
        m.faceAngle.y = m.intendedYaw
    end
    if e.actionTick < 7 then
        spawn_particle(m, PARTICLE_SPARKLES)
        e.gfxAngleY = e.gfxAngleY + 0x1600
        m.marioObj.header.gfx.angle.y = e.gfxAngleY
    end

    if e.actionTick < 10 then m.vel.y = 0 else set_mario_animation(m, CHAR_ANIM_GENERAL_FALL) end
    if e.actionTick > 3 then make_air_actionable(m) end
end
hook_mario_action(ACT_CAP_THROW_AIR_H, {every_frame = act_cap_throw_air_h})


local function act_cap_throw_ground_h(m)
    local e = gExtrasStates[m.playerIndex]

    if e.actionTick == 0 then
        play_character_sound(m, CHAR_SOUND_WAH2)

        m.marioObj.header.gfx.angle.y = m.faceAngle.y 
        m.faceAngle.y = m.intendedYaw
        m.forwardVel = m.forwardVel / 2
    end
    if e.actionTick < 7 then
        spawn_particle(m, PARTICLE_SPARKLES)
        e.gfxAngleY = e.gfxAngleY + 0x1600
        m.marioObj.header.gfx.angle.y = e.gfxAngleY
    end

    local stepResult = perform_ground_step(m)
    if (stepResult == GROUND_STEP_LEFT_GROUND) then
        set_mario_action(m, ACT_FREEFALL, 0);
        set_character_animation(m, CHAR_ANIM_GENERAL_FALL);    
    elseif (stepResult == GROUND_STEP_NONE) then
        set_mario_animation(m, CHAR_ANIM_GROUND_THROW);
    elseif (stepResult == GROUND_STEP_HIT_WALL) then
        spawn_particle(m, PARTICLE_VERTICAL_STAR)
        set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0);
        m.actionTimer = 0;
    end
    if e.actionTick > 10 then
        return set_mario_action(m, ACT_WALKING, 0)
    end
    if e.actionTick > 3 then make_actionable(m) end
end
hook_mario_action(ACT_CAP_THROW_GROUND_H, {every_frame = act_cap_throw_ground_h})

local function act_roll_h(m)
    local e = gExtrasStates[m.playerIndex]
    local mag = (m.controller.stickMag) / 64
    local buttonP = m.controller.buttonPressed
    local buttonD = m.controller.buttonDown

    if e.actionTick == 0 then
        play_character_sound(m, CHAR_SOUND_WAH2)
    end

    update_rolling_speed(m);
    spawn_particle(m, PARTICLE_DUST)

    if buttonD & Z_TRIG == 0 or mag < 1 then
        e.rollEndTimerOnZ = e.rollEndTimerOnZ + 1
        if e.rollEndTimerOnZ > 10 then
            if mag > 0 then
                mario_set_forward_vel(m, m.forwardVel)
                set_mario_action(m, ACT_WALKING, 0)
            else
                set_mario_action(m, ACT_IDLE, 0)
            end
            e.rollEndTimerOnZ = 0
        end
    end

    if buttonP & (X_BUTTON | Y_BUTTON) ~= 0 then
        set_mario_action(m, ACT_ROLL_BOOST, 0)
        e.rollendtimer = 0

    else
        e.rollendtimer = e.rollendtimer + 1
        if e.rollendtimer > 60 then
            if mag > 0 then
                mario_set_forward_vel(m, m.forwardVel)
                set_mario_action(m, ACT_WALKING, 0)
            else
                set_mario_action(m, ACT_IDLE, 0)
            end
            e.rollendtimer = 0
        end
    end

    if m.forwardVel > 50 then
        e.rollendtimer = 0
    end

    if buttonP & A_BUTTON ~= 0 then
        set_mario_action(m, ACT_LONG_JUMP, 0)
    end

    local stepResult = perform_ground_step(m)
    if (stepResult == GROUND_STEP_LEFT_GROUND) then
        set_mario_action(m, ACT_FREEFALL, 0);
        set_character_animation(m, CHAR_ANIM_GENERAL_FALL);    
    elseif (stepResult == GROUND_STEP_NONE) then
        set_mario_animation(m, CHAR_ANIM_FORWARD_SPINNING);
    elseif (stepResult == GROUND_STEP_HIT_WALL) then
        spawn_particle(m, PARTICLE_VERTICAL_STAR)
        set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0);
        m.actionTimer = 0;
    end
end
hook_mario_action(ACT_ROLL_H, {every_frame = act_roll_h, gravity = nil})

local function act_roll_boost(m)
    local e = gExtrasStates[m.playerIndex]
    local mag = (m.controller.stickMag) / 64
    local buttonP = m.controller.buttonPressed
    local buttonD = m.controller.buttonDown

    if e.actionTick == 0 then
        play_character_sound(m, CHAR_SOUND_WAH2)
        spawn_particle(m, PARTICLE_VERTICAL_STAR)
        m.vel.y = 20
        m.forwardVel = m.forwardVel + 10
    end

    local stepResult = common_air_action_step(m, ACT_FREEFALL_LAND, CHAR_ANIM_DIVE, AIR_STEP_NONE)
    if stepResult == AIR_STEP_LANDED then
        set_mario_action(m, ACT_ROLL_H, 0)
        return
    end
end
hook_mario_action(ACT_ROLL_BOOST, {every_frame = act_roll_boost})

local function act_wall_slide(m)
    local e = gExtrasStates[m.playerIndex]
    local buttonD = m.controller.buttonDown
    local buttonP = m.controller.buttonPressed

    common_air_action_step(m, ACT_FREEFALL, CHAR_ANIM_START_WALLKICK, STEP_TYPE_AIR)

    if buttonD & Z_TRIG ~= 0 then
        set_mario_action(m, ACT_FREEFALL, 0)
        return
    end

    if e.actionTick > 2 then
        m.vel.y = m.vel.y * 0.9
        spawn_particle(m, PARTICLE_DUST)
    else
        m.vel.y = -2
    end

    if buttonP & A_BUTTON ~= 0 then
        set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    end
    m.wallKickTimer = 0
end
hook_mario_action(ACT_WALL_SLIDE, {every_frame = act_wall_slide})

local function gp_jump_rotation(m)
    local e = gExtrasStates[m.playerIndex]

    if m.action == ACT_JUMP and m.prevAction == ACT_GROUND_POUND_LAND then
        -- Saves rotation to Extra States
        e.gfxAngleY = e.gfxAngleY + 0x1600
        -- Applies rotation
        m.marioObj.header.gfx.angle.y = e.gfxAngleY
        if m.vel.y < 0 then
            m.marioObj.header.gfx.angle.y = m.faceAngle.y
            e.gfxAngleY = m.faceAngle.y
        end
    end
end

local function hmario_before_set_action(m, inc)
    local e = gExtrasStates[m.playerIndex]
    local mag = (m.controller.stickMag) / 64
    local buttonP = m.controller.buttonPressed
    local buttonD = m.controller.buttonDown

    if inc == ACT_SOFT_BONK then
        m.faceAngle.y = m.faceAngle.y + 0x8000
        m.marioObj.header.gfx.angle.y = m.faceAngle.y
        m.pos.x = m.pos.x
        m.pos.z = m.pos.z
        m.vel.x = 0
        m.vel.z = 0
        m.forwardVel = 0

        return ACT_WALL_SLIDE
    end
end

local function hmario_on_set_action(m)
    local e = gExtrasStates[m.playerIndex]
    local mag = (m.controller.stickMag) / 64
    local buttonP = m.controller.buttonPressed
    local buttonD = m.controller.buttonDown
    
    if m.action == ACT_STEEP_JUMP then
        set_mario_action(m, ACT_JUMP, 0)
    end

    if m.action == ACT_DIVE_SLIDE then
        spawn_particle(m, PARTICLE_MIST_CIRCLE)
        if mag > 0 then
            set_mario_action(m, ACT_WALKING, 0)
        else
            set_mario_action(m, ACT_IDLE, 0)
        end

        if buttonD & Z_TRIG ~= 0 then
            set_mario_action(m, ACT_ROLL_H, 0)
            mario_set_forward_vel(m, m.forwardVel)
        end
    end

    if m.action == ACT_LONG_JUMP_LAND then
        if buttonD & Z_TRIG ~= 0 then
            set_mario_action(m, ACT_ROLL_H, 0)
            mario_set_forward_vel(m, m.forwardVel)
        end
    end

    if m.action == ACT_WALL_KICK_AIR then
        m.vel.y = 37
        m.forwardVel = 30
    end

    if bonkActs[m.action] then
        mario_set_forward_vel(m, 0)
        if e.actionTick == 0 then
            m.vel.y = 5
        end
    end
end 

local function update_hmario(m)
    local e = gExtrasStates[m.playerIndex]
    local mag = (m.controller.stickMag) / 64
    local buttonP = m.controller.buttonPressed
    local buttonD = m.controller.buttonDown
    
    gp_jump_rotation(m)
    allow_cap_throw(m)
    
    m.peakHeight = m.pos.y
    
    -- Global Action Timer 
    e.actionTick = e.actionTick + 1
    if e.prevFrameAction ~= m.action then
        e.prevFrameAction = m.action
        e.actionTick = 0
    end

    if m.action == ACT_GROUND_POUND then
        if buttonP & (X_BUTTON | Y_BUTTON) ~= 0 then
            spawn_particle(m, PARTICLE_MIST_CIRCLE)
            set_mario_action(m, ACT_DIVE, 0)
            m.vel.y = 29
            m.forwardVel = 39
        end
    end

    if m.action == ACT_CROUCH_SLIDE then
        if buttonP & (X_BUTTON | Y_BUTTON) ~= 0 then
            spawn_particle(m, PARTICLE_MIST_CIRCLE)
            set_mario_action(m, ACT_ROLL_H, 0)
            m.forwardVel = m.forwardVel + 20
        end
    end

    if m.action == ACT_GROUND_POUND_LAND then
        if buttonP & (X_BUTTON | Y_BUTTON) ~= 0 then
            spawn_particle(m, PARTICLE_HORIZONTAL_STAR)
            set_mario_action(m, ACT_ROLL_H, 0)
            m.forwardVel = 70
        end

        if buttonP & A_BUTTON ~= 0 then
            spawn_particle(m, PARTICLE_HORIZONTAL_STAR)
            set_mario_action(m, ACT_JUMP, 0)
            m.vel.y = 70
        end
    end

    if jumpActs[m.action] then
        if e.actionTick < 3 then
            spawn_particle(m, PARTICLE_DUST)
        end

        if e.actionTick == 0 then jump_gravity(m) end

        if m.action ~= (ACT_BACKFLIP | ACT_SIDE_FLIP | ACT_LONG_JUMP) then 
            set_turn_speed(m, 0x500)
            if e.actionTick > 10 then
                set_turn_speed(m, 0x800)
            end
        end
        make_air_actionable(m)
    end

    if m.action == ACT_LONG_JUMP then
        if e.actionTick == 0 then
            m.forwardVel = m.forwardVel + 10
        end
        if e.actionTick < 3 then
            spawn_particle(m, PARTICLE_DUST)
        end
        set_turn_speed(m, 0x200)
    end

    if m.action == ACT_WALKING then
        set_turn_speed(m, 0x800)
        m.particleFlags = m.particleFlags | PARTICLE_DUST
    end

    if jumpLandActsSet[m.action] then
        if e.actionTick == 1 then
            spawn_particle(m, PARTICLE_DUST)
        end
        make_actionable(m)
    end
end

_G.charSelect.character_hook_moveset(CHAR_HONIMARIO, HOOK_BEFORE_SET_MARIO_ACTION, hmario_before_set_action)
_G.charSelect.character_hook_moveset(CHAR_HONIMARIO, HOOK_MARIO_UPDATE, update_hmario)
_G.charSelect.character_hook_moveset(CHAR_HONIMARIO, HOOK_ON_LEVEL_INIT, reset_hmario_states)
_G.charSelect.character_hook_moveset(CHAR_HONIMARIO, HOOK_ON_SET_MARIO_ACTION, hmario_on_set_action)
