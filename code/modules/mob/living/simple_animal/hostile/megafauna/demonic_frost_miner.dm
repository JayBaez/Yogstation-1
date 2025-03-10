/*

Difficulty: Extremely Hard

*/

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner
	name = "demonic-frost miner"
	desc = "An extremely geared miner, driven crazy or possessed by the demonic forces here, either way a terrifying enemy."
	health = 1500
	maxHealth = 1500
	icon_state = "demonic_miner"
	icon_living = "demonic_miner"
	icon = 'icons/mob/icemoon/icemoon_monsters.dmi'
	attacktext = "pummels"
	attack_sound = 'sound/weapons/sonic_jackhammer.ogg'
	mob_biotypes = list(MOB_ORGANIC,MOB_HUMANOID)
	light_color = "#E4C7C5"
	movement_type = GROUND
	weather_immunities = list("snow")
	speak_emote = list("roars")
	armour_penetration = 100
	melee_damage_lower = 10
	melee_damage_upper = 10
	aggro_vision_range = 36 // large vision range so combat doesn't abruptly end when someone runs a bit away
	rapid_melee = 4
	speed = 20
	move_to_delay = 20
	ranged = TRUE
	crusher_loot = list(/obj/effect/decal/remains/plasma, /obj/item/crusher_trophy/ice_block_talisman)
	loot = list(/obj/effect/decal/remains/plasma)
	wander = FALSE
	del_on_death = TRUE
	blood_volume = BLOOD_VOLUME_GENERIC
	var/projectile_speed_multiplier = 1
	var/enraged = FALSE
	var/enraging = FALSE
	deathmessage = "falls to the ground, decaying into plasma particles."
	deathsound = "bodyfall"
	attack_action_types = list(/datum/action/innate/megafauna_attack/frost_orbs,
							   /datum/action/innate/megafauna_attack/snowball_machine_gun,
							   /datum/action/innate/megafauna_attack/ice_shotgun)

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/Initialize()
	. = ..()
	AddComponent(/datum/component/knockback, 7, FALSE)
	AddComponent(/datum/component/lifesteal, 50)

/datum/action/innate/megafauna_attack/frost_orbs
	name = "Fire Frost Orbs"
	icon_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	chosen_message = span_colossus("You are now sending out frost orbs to track in on a target.")
	chosen_attack_num = 1

/datum/action/innate/megafauna_attack/snowball_machine_gun
	name = "Fire Snowball Machine Gun"
	icon_icon = 'icons/obj/guns/energy.dmi'
	button_icon_state = "kineticgun"
	chosen_message = span_colossus("You are now firing a snowball machine gun at a target.")
	chosen_attack_num = 2

/datum/action/innate/megafauna_attack/ice_shotgun
	name = "Fire Ice Shotgun"
	icon_icon = 'icons/obj/guns/projectile.dmi'
	button_icon_state = "shotgun"
	chosen_message = span_colossus("You are now firing shotgun ice blasts.")
	chosen_attack_num = 3

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/OpenFire()
	check_enraged()
	projectile_speed_multiplier = 1 + enraged / 2 // ranges from normal to 2x speed
	SetRecoveryTime(100, 100)

	if(client)
		switch(chosen_attack)
			if(1)
				frost_orbs()
			if(2)
				snowball_machine_gun()
			if(3)
				ice_shotgun()
		return

	var/easy_attack = prob(80 - enraged * 40)
	chosen_attack = rand(1, 3)
	switch(chosen_attack)
		if(1)
			if(easy_attack)
				frost_orbs(10, 8)
			else
				frost_orbs(5, 16)
		if(2)
			if(easy_attack)
				snowball_machine_gun()
			else
				INVOKE_ASYNC(src, .proc/ice_shotgun, 5, list(list(-180, -140, -100, -60, -20, 20, 60, 100, 140), list(-160, -120, -80, -40, 0, 40, 80, 120, 160)))
				snowball_machine_gun(5 * 8, 5)
		if(3)
			if(easy_attack)
				ice_shotgun()
			else
				ice_shotgun(5, list(list(0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330), list(-30, -15, 0, 15, 30)))

/obj/item/projectile/frost_orb
	name = "frost orb"
	icon_state = "ice_1"
	damage = 20
	armour_penetration = 100
	speed = 10
	homing_turn_speed = 30
	damage_type = BURN

/obj/item/projectile/frost_orb/on_hit(atom/target, blocked = FALSE)
	. = ..()
	if(isturf(target) || isobj(target))
		target.ex_act(EXPLODE_HEAVY)

/obj/item/projectile/snowball
	name = "machine-gun snowball"
	icon_state = "nuclear_particle"
	damage = 5
	armour_penetration = 100
	speed = 4
	damage_type = BRUTE

/obj/item/projectile/snowball/fast
	speed = 2

/obj/item/projectile/ice_blast
	name = "ice blast"
	icon_state = "ice_2"
	damage = 15
	armour_penetration = 100
	speed = 4
	damage_type = BRUTE

/obj/item/projectile/ice_blast/on_hit(atom/target, blocked = FALSE)
	. = ..()
	if(isturf(target) || isobj(target))
		target.ex_act(EXPLODE_HEAVY)

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/ex_act(severity, target)
	adjustBruteLoss(30 * severity - 120)
	visible_message(span_danger("[src] absorbs the explosion!"), span_userdanger("You absorb the explosion!"))
	return

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/Goto(target, delay, minimum_distance)
	if(!enraging)
		. = ..()

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/MoveToTarget(list/possible_targets)
	if(!enraging)
		. = ..()

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/Move()
	if(!enraging)
		. = ..()

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/proc/frost_orbs(added_delay = 10, shoot_times = 8)
	for(var/i in 1 to shoot_times)
		var/turf/startloc = get_turf(src)
		var/turf/endloc = get_turf(target)
		if(!endloc)
			break
		var/obj/item/projectile/frost_orb/P = new /obj/item/projectile/frost_orb(startloc)
		P.preparePixelProjectile(endloc, startloc)
		P.firer = src
		if(target)
			P.original = target
		P.set_homing_target(target)
		P.fire(rand(0, 360))
		addtimer(CALLBACK(P, /obj/item/projectile/frost_orb/proc/orb_explosion, projectile_speed_multiplier), 20) // make the orbs home in after a second
		SLEEP_CHECK_DEATH(added_delay)
	SetRecoveryTime(40, 60)

/obj/item/projectile/frost_orb/proc/orb_explosion(projectile_speed_multiplier)
	var/list/spread = list(0, 60, 120, 180, 240, 300)
	for(var/angle in spread)
		var/turf/startloc = get_turf(src)
		var/turf/endloc = get_turf(original)
		if(!startloc || !endloc)
			break
		var/obj/item/projectile/P = new /obj/item/projectile/ice_blast(startloc)
		P.speed /= projectile_speed_multiplier
		P.preparePixelProjectile(endloc, startloc, null, angle + rand(-10, 10))
		P.firer = firer
		if(original)
			P.original = original
		P.fire()
	qdel(src)

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/proc/snowball_machine_gun(shots = 60, spread = 45)
	for(var/i in 1 to shots)
		var/turf/startloc = get_turf(src)
		var/turf/endloc = get_turf(target)
		if(!endloc)
			break
		var/obj/item/projectile/P = new /obj/item/projectile/snowball(startloc)
		P.speed /= projectile_speed_multiplier
		P.preparePixelProjectile(endloc, startloc, null, rand(-spread, spread))
		P.firer = src
		if(target)
			P.original = target
		P.fire()
		SLEEP_CHECK_DEATH(1)
	SetRecoveryTime(15, 15)

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/proc/ice_shotgun(shots = 5, list/patterns = list(list(-40, -20, 0, 20, 40), list(-30, -10, 10, 30)))
	for(var/i in 1 to shots)
		var/list/pattern = patterns[i % length(patterns) + 1] // alternating patterns
		for(var/spread in pattern)
			var/turf/startloc = get_turf(src)
			var/turf/endloc = get_turf(target)
			if(!endloc)
				break
			var/obj/item/projectile/P = new /obj/item/projectile/ice_blast(startloc)
			P.speed /= projectile_speed_multiplier
			P.preparePixelProjectile(endloc, startloc, null, spread)
			P.firer = src
			if(target)
				P.original = target
			P.fire()
		SLEEP_CHECK_DEATH(8)
	SetRecoveryTime(15, 20)

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/proc/check_enraged()
	if(health <= maxHealth*0.25 && !enraged)
		SetRecoveryTime(80, 80)
		adjustHealth(-maxHealth)
		enraged = TRUE
		enraging = TRUE
		animate(src, pixel_y = pixel_y + 96, time = 100, easing = ELASTIC_EASING)
		spin(100, 10)
		SLEEP_CHECK_DEATH(60)
		playsound(src, 'sound/effects/explosion3.ogg', 100, TRUE)
		overlays += mutable_appearance('icons/effects/effects.dmi', "curse")
		animate(src, pixel_y = pixel_y - 96, time = 8, flags = ANIMATION_END_NOW)
		spin(8, 2)
		SLEEP_CHECK_DEATH(8)
		for(var/mob/living/L in viewers(src))
			shake_camera(L, 3, 2)
		playsound(src, 'sound/effects/meteorimpact.ogg', 100, TRUE)
		setMovetype(movement_type | FLYING)
		enraging = FALSE
		adjustHealth(-maxHealth)

/mob/living/simple_animal/hostile/megafauna/demonic_frost_miner/death(gibbed, list/force_grant)
	if(health > 0)
		return
	else
		var/turf/T = get_turf(src)
		var/loot = rand(1, 3)
		switch(loot)
			if(1)
				new /obj/item/gun/energy/snowball_machine_gun(T)
			if(2)
				new /obj/item/clothing/shoes/winterboots/ice_boots/speedy(T)
			if(3)
				new /obj/item/pickaxe/drill/jackhammer/demonic(T)
		. = ..()

/obj/item/gun/energy/snowball_machine_gun
	name = "snowball machine gun"
	desc = "A self-charging poorly-rigged energy gun that fires energy particles that look like snowballs."
	icon_state = "freezegun"
	ammo_type = list(/obj/item/ammo_casing/energy/snowball)
	selfcharge = TRUE
	charge_delay = 4
	burst_size = 3
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF

/obj/item/ammo_casing/energy/snowball
	projectile_type = /obj/item/projectile/snowball/fast
	select_name = "freeze"
	e_cost = 20
	delay = 0.5
	fire_sound = 'sound/weapons/sonic_jackhammer.ogg'

/obj/item/clothing/shoes/winterboots/ice_boots/speedy
	name = "cursed ice hiking boots"
	desc = "A pair of winter boots contractually made by a devil, they cannot be taken off once put on."
	slowdown = SHOES_SLOWDOWN - 1

/obj/item/clothing/shoes/winterboots/ice_boots/speedy/Initialize()
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, CURSED_ITEM_TRAIT)

/obj/item/pickaxe/drill/jackhammer/demonic
	name = "demonic jackhammer"
	desc = "Cracks rocks at an inhuman speed, as well as being enhanced for combat purposes."
	toolspeed = 0

/obj/item/pickaxe/drill/jackhammer/demonic/Initialize()
	..()
	AddComponent(/datum/component/knockback, 4, FALSE)
	AddComponent(/datum/component/lifesteal, 5)

/obj/item/crusher_trophy/ice_block_talisman
	name = "ice block talisman"
	desc = "A glowing trinket that a demonic miner had on him, it seems he couldn't utilize it for whatever reason."
	icon_state = "ice_trap_talisman"
	denied_type = /obj/item/crusher_trophy/ice_block_talisman

/obj/item/crusher_trophy/ice_block_talisman/effect_desc()
	return "mark detonation to freeze a creature in a block of ice for a period, preventing them from moving"

/obj/item/crusher_trophy/ice_block_talisman/on_mark_detonation(mob/living/target, mob/living/user)
	target.apply_status_effect(/datum/status_effect/ice_block_talisman)

/datum/status_effect/ice_block_talisman
	id = "ice_block_talisman"
	duration = 25
	status_type = STATUS_EFFECT_REFRESH
	alert_type = /obj/screen/alert/status_effect/ice_block_talisman
	var/icon/cube

/obj/screen/alert/status_effect/ice_block_talisman
	name = "Frozen Solid"
	desc = "You're frozen inside an ice cube, and cannot move!"
	icon_state = "frozen"

/datum/status_effect/ice_block_talisman/on_apply()
	RegisterSignal(owner, COMSIG_MOVABLE_PRE_MOVE, .proc/owner_moved)
	if(!owner.stat)
		to_chat(owner, span_userdanger("You become frozen in a cube!"))
	cube = icon('icons/effects/freeze.dmi', "ice_cube")
	var/icon/size_check = icon(owner.icon, owner.icon_state)
	cube.Scale(size_check.Width(), size_check.Height())
	owner.add_overlay(cube)
	return ..()

/datum/status_effect/ice_block_talisman/proc/owner_moved()
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/status_effect/ice_block_talisman/on_remove()
	if(!owner.stat)
		to_chat(owner, span_notice("The cube melts!"))
	owner.cut_overlay(cube)
	UnregisterSignal(owner, COMSIG_MOVABLE_PRE_MOVE)