/obj/item/capture_sack
	name = "capture sack"
	desc = "A broad cloth sack with a draw-rope and carrying straps. It is meant to move a subdued captive quickly."
	icon = 'icons/roguetown/clothing/storage.dmi'
	icon_state = "rucksack_tied_sling"
	item_state = "rucksack"
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BACK|ITEM_SLOT_BELT|ITEM_SLOT_HIP
	resistance_flags = FLAMMABLE
	max_integrity = 150
	sewrepair = TRUE
	dropshrink = 0.8
	experimental_onback = TRUE
	experimental_onhip = TRUE
	var/mob/living/occupant
	var/mob/living/current_carrier
	var/escaping = FALSE
	var/partial_bound_escape_time = 45 SECONDS
	var/bound_escape_time = 2 MINUTES
	var/carry_slowdown = 0.15
	var/base_escape_time = 18 SECONDS
	var/strong_escape_time = 8 SECONDS
	var/blade_escape_time = 4 SECONDS
	var/easy_to_cut = TRUE
	var/movespeed_id

/obj/item/capture_sack/Initialize(mapload)
	movespeed_id = "capture_sack_[REF(src)]"
	return ..()

/obj/item/capture_sack/Destroy()
	remove_carrier_slowdown()
	if(occupant)
		release_occupant(FALSE)
	return ..()

/obj/item/capture_sack/examine(mob/user)
	. = ..()
	if(occupant)
		. += span_warning("It bulges and shifts; someone is trapped inside.")
		. += span_notice("Use it in hand to loosen the mouth and release them.")
	else
		. += span_notice("Use it on a living target to pull the sack over them. A moving target will interrupt the attempt.")

/obj/item/capture_sack/getonmobprop(tag)
	. = ..()
	if(!tag)
		return
	switch(tag)
		if("gen")
			return list("shrink" = 0.75, "sx" = -5, "sy" = -5, "nx" = 5, "ny" = -4, "wx" = -3, "wy" = -5, "ex" = 3, "ey" = -5, "northabove" = 0, "southabove" = 1, "eastabove" = 1, "westabove" = 0, "nturn" = 0, "sturn" = 0, "wturn" = 0, "eturn" = 0, "nflip" = 8, "sflip" = 0, "wflip" = 0, "eflip" = 8)
		if("onback")
			return list("shrink" = 0.85, "sx" = 0, "sy" = 1, "nx" = 0, "ny" = 2, "wx" = 2, "wy" = 1, "ex" = -2, "ey" = 1, "northabove" = 1, "southabove" = 0, "eastabove" = 0, "westabove" = 0, "nturn" = 0, "sturn" = 0, "wturn" = 0, "eturn" = 0, "nflip" = 0, "sflip" = 0, "wflip" = 0, "eflip" = 8)
		if("onbelt")
			return list("shrink" = 0.55, "sx" = -3, "sy" = -6, "nx" = 3, "ny" = -6, "wx" = 0, "wy" = -6, "ex" = 1, "ey" = -6, "northabove" = 0, "southabove" = 1, "eastabove" = 1, "westabove" = 0, "nturn" = 0, "sturn" = 0, "wturn" = 0, "eturn" = 0, "nflip" = 0, "sflip" = 0, "wflip" = 0, "eflip" = 8)

/obj/item/capture_sack/proc/occupant_is_small()
	if(!occupant)
		return TRUE
	if(occupant.mob_size <= MOB_SIZE_SMALL)
		return TRUE
	if(ishuman(occupant))
		var/mob/living/carbon/human/H = occupant
		return iskobold(H) || isgoblinp(H) || iscritter(H) || isdwarf(H)
	return FALSE

/obj/item/capture_sack/mob_can_equip(mob/living/M, mob/living/equipper, slot, disable_warning = FALSE, bypass_equip_delay_self = FALSE)
	if(occupant && !occupant_is_small() && !(slot in list(SLOT_BACK, SLOT_BACK_L, SLOT_BACK_R)))
		if(!disable_warning)
			to_chat(M, span_warning("[src] is too bulky to secure anywhere but my back with a full-sized captive inside."))
		return FALSE
	return ..()

/obj/item/capture_sack/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	icon_state = (slot == SLOT_BELT) ? "satchel" : initial(icon_state)
	update_carrier_slowdown()

/obj/item/capture_sack/dropped(mob/user, silent = FALSE)
	. = ..()
	icon_state = initial(icon_state)
	update_carrier_slowdown()

/obj/item/capture_sack/attack(mob/living/target, mob/living/user)
	if(!istype(target) || target == user)
		return ..()
	if(occupant)
		to_chat(user, span_warning("[src] already holds someone."))
		return TRUE
	if(target.mob_size > MOB_SIZE_HUMAN || target.anchored || target.buckled || target.has_buckled_mobs())
		to_chat(user, span_warning("[target] will not fit into [src]."))
		return TRUE
	if(!isturf(target.loc) || !user.Adjacent(target))
		return TRUE

	var/capture_time = 2 SECONDS
	if(target.stat == CONSCIOUS && (target.mobility_flags & MOBILITY_STAND))
		capture_time = 6 SECONDS
	if(ishuman(target))
		var/mob/living/carbon/human/H = target
		if(H.wear_armor)
			capture_time += H.wear_armor.armor_class * 2 SECONDS
	capture_time += max(0, target.STASTR - user.STASTR) * 0.5 SECONDS

	user.visible_message(
		span_warning("[user] starts wrestling [src] over [target]!"),
		span_warning("I start wrestling [src] over [target]. They must remain still!"),
	)
	to_chat(target, span_userdanger("[user] is trying to stuff me into [src]! Move away to stop them!"))
	if(!do_after_mob(user, list(target, src), capture_time))
		return TRUE
	if(occupant || QDELETED(target) || QDELETED(src) || !user.Adjacent(target) || target.mob_size > MOB_SIZE_HUMAN)
		return TRUE
	if(user.get_active_held_item() != src)
		return TRUE

	occupant = target
	target.stop_pulling()
	target.forceMove(src)
	add_fingerprint(user)
	log_combat(user, target, "stuffed into [src]", addition = "([target.stat == DEAD ? "DEAD" : "ALIVE"])")
	user.visible_message(
		span_danger("[user] cinches [src] shut around [target]!"),
		span_notice("I cinch [src] shut around [target]."),
	)
	to_chat(target, span_userdanger("I am trapped inside [src]! I can resist to struggle free."))
	playsound(src, 'sound/foley/equip/rummaging-01.ogg', 80, TRUE)
	update_carrier_slowdown()
	return TRUE

/obj/item/capture_sack/attack_self(mob/user)
	if(!occupant)
		to_chat(user, span_notice("[src] is empty."))
		return TRUE
	user.visible_message(
		span_notice("[user] loosens [src] and lets [occupant] out."),
		span_notice("I loosen [src] and let [occupant] out."),
	)
	release_occupant()
	return TRUE

/obj/item/capture_sack/attack_right(mob/user)
	return attack_self(user)

/obj/item/capture_sack/relaymove(mob/user, direction)
	if(user == occupant)
		container_resist(user)
		return
	return ..()

/obj/item/capture_sack/container_resist(mob/living/user)
	if(user != occupant || escaping)
		return
	escaping = TRUE
	user.changeNext_move(CLICK_CD_BREAKOUT)
	user.last_special = world.time + CLICK_CD_BREAKOUT

	var/obj/item/rogueweapon/huntingknife/cutting_blade
	var/obj/item/held = user.get_active_held_item()
	if(istype(held, /obj/item/rogueweapon/huntingknife))
		cutting_blade = held

	var/escape_time = base_escape_time
	var/escape_method = "wrestle"
	if(cutting_blade)
		escape_time = blade_escape_time
		escape_method = "cut"
	else if(user.STASTR >= 15)
		escape_time = max(3 SECONDS, strong_escape_time - ((user.STASTR - 15) * 1 SECONDS))
	if(iscarbon(user))
		var/mob/living/carbon/carbon_user = user
		if(carbon_user.handcuffed && carbon_user.legcuffed)
			escape_time = bound_escape_time
		else if(carbon_user.handcuffed || carbon_user.legcuffed)
			escape_time = partial_bound_escape_time

	if(!cutting_blade && !prob(clamp(user.STASTR * 5, 5, 95)))
		visible_message(span_warning("[src] jostles as someone struggles inside, but they cannot find enough leverage!"))
		to_chat(user, span_warning("I strain against [src], but cannot find enough leverage."))
		escaping = FALSE
		return

	visible_message(span_warning("[src] jerks and thrashes as someone struggles inside!"))
	to_chat(user, span_warning("I begin to [escape_method] my way out of [src]..."))
	if(!do_after(user, escape_time, needhand = !!cutting_blade, target = user) || user.loc != src)
		escaping = FALSE
		return
	if(cutting_blade && !QDELETED(cutting_blade))
		cutting_blade.take_damage(easy_to_cut ? 2 : 8, BRUTE, "blunt")
	visible_message(span_danger("[user] [escape_method == "cut" ? "cuts" : "tears"] free of [src]!"))
	release_occupant()
	escaping = FALSE

/obj/item/capture_sack/proc/release_occupant(play_sound = TRUE)
	if(!occupant)
		return FALSE
	var/mob/living/released = occupant
	occupant = null
	released.forceMove(get_turf(src))
	released.reset_perspective()
	if(play_sound)
		playsound(src, 'sound/foley/cloth_rip.ogg', 55, TRUE)
	update_carrier_slowdown()
	return TRUE

/obj/item/capture_sack/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(isliving(arrived) && !occupant)
		occupant = arrived
		update_carrier_slowdown()

/obj/item/capture_sack/Exited(atom/movable/gone, atom/new_loc)
	. = ..()
	if(gone == occupant)
		occupant = null
		escaping = FALSE
		update_carrier_slowdown()

/obj/item/capture_sack/Moved(atom/old_loc, direction, forced = FALSE, list/old_locs, momentum_change)
	. = ..()
	update_carrier_slowdown()

/obj/item/capture_sack/proc/update_carrier_slowdown()
	var/mob/living/new_carrier = isliving(loc) ? loc : null
	if(current_carrier && (current_carrier != new_carrier || !occupant))
		UnregisterSignal(current_carrier, COMSIG_MOVABLE_MOVED)
		current_carrier.remove_movespeed_modifier(movespeed_id)
		current_carrier = null
	if(new_carrier && occupant)
		if(current_carrier != new_carrier)
			current_carrier = new_carrier
			RegisterSignal(current_carrier, COMSIG_MOVABLE_MOVED, PROC_REF(carrier_moved))
		current_carrier.add_movespeed_modifier(movespeed_id, override = TRUE, multiplicative_slowdown = carry_slowdown)

/obj/item/capture_sack/proc/carrier_moved(datum/source)
	SIGNAL_HANDLER
	if(escaping && occupant?.doing)
		occupant.doing = FALSE
		visible_message(span_warning("[src] jostles against its moving carrier, spoiling the captive's escape attempt!"))
		to_chat(occupant, span_warning("The movement throws me around and ruins my escape attempt."))

/obj/item/capture_sack/proc/remove_carrier_slowdown()
	if(current_carrier)
		UnregisterSignal(current_carrier, COMSIG_MOVABLE_MOVED)
		current_carrier.remove_movespeed_modifier(movespeed_id)
		current_carrier = null

/obj/item/capture_sack/chain
	name = "chain capture sack"
	desc = "A capture sack caged in close-linked chain. It is heavy, stubborn, and difficult to cut from within."
	color = "#889096"
	resistance_flags = FIRE_PROOF
	max_integrity = 400
	sewrepair = FALSE
	anvilrepair = /datum/skill/craft/blacksmithing
	base_escape_time = 60 SECONDS
	strong_escape_time = 35 SECONDS
	blade_escape_time = 24 SECONDS
	easy_to_cut = FALSE
	carry_slowdown = 0.15

/obj/item/capture_sack/chain/iron
	name = "iron chain capture sack"
	smeltresult = /obj/item/ingot/iron

/obj/item/capture_sack/chain/steel
	name = "steel chain capture sack"
	color = "#aab2b8"
	smeltresult = /obj/item/ingot/steel
	max_integrity = 500
	base_escape_time = 70 SECONDS
	strong_escape_time = 40 SECONDS
	blade_escape_time = 28 SECONDS

/datum/crafting_recipe/roguetown/sewing/capture_sack
	display_category = ITEM_CAT_TAILOR_MISC
	name = "capture sack"
	result = list(/obj/item/capture_sack)
	reqs = list(
		/obj/item/natural/cloth = 5,
		/obj/item/rope = 1,
	)
	craftdiff = 2

/datum/anvil_recipe/engineering/capture_sack_iron
	name = "Capture Sack, Chain-Reinforced, Iron (+1 Capture Sack)"
	req_bar = /obj/item/ingot/iron
	additional_items = list(/obj/item/capture_sack)
	created_item = /obj/item/capture_sack/chain/iron
	craftdiff = SKILL_LEVEL_APPRENTICE

/datum/anvil_recipe/engineering/capture_sack_steel
	name = "Capture Sack, Chain-Reinforced, Steel (+1 Capture Sack)"
	req_bar = /obj/item/ingot/steel
	additional_items = list(/obj/item/capture_sack)
	created_item = /obj/item/capture_sack/chain/steel
	craftdiff = SKILL_LEVEL_JOURNEYMAN
