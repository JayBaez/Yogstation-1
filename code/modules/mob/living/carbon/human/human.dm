/mob/living/carbon/human
	name = "Unknown"
	real_name = "Unknown"
	icon = 'icons/mob/human.dmi'
	icon_state = "human_basic"
	appearance_flags = KEEP_TOGETHER|TILE_BOUND|PIXEL_SCALE|LONG_GLIDE

/mob/living/carbon/human/Initialize()
	add_verb(src, /mob/living/proc/mob_sleep)
	add_verb(src, /mob/living/proc/lay_down)

	icon_state = ""		//Remove the inherent human icon that is visible on the map editor. We're rendering ourselves limb by limb, having it still be there results in a bug where the basic human icon appears below as south in all directions and generally looks nasty.

	//initialize limbs first
	create_bodyparts()

	setup_human_dna()

	if(dna.species)
		set_species(dna.species.type)

	//initialise organs
	create_internal_organs() //most of it is done in set_species now, this is only for parent call
	physiology = new()

	. = ..()

	RegisterSignal(src, COMSIG_COMPONENT_CLEAN_FACE_ACT, .proc/clean_face)
	AddComponent(/datum/component/personal_crafting)

/mob/living/carbon/human/proc/setup_human_dna()
	//initialize dna. for spawned humans; overwritten by other code
	create_dna(src)
	randomize_human(src)
	dna.initialize_dna()

/mob/living/carbon/human/ComponentInitialize()
	. = ..()
	if(!(CONFIG_GET(flag/disable_human_mood)))
		AddComponent(/datum/component/mood)

/mob/living/carbon/human/Destroy()
	QDEL_NULL(physiology)
	return ..()


/mob/living/carbon/human/prepare_data_huds()
	//Update med hud images...
	..()
	//...sec hud images...
	sec_hud_set_ID()
	sec_hud_set_implants()
	sec_hud_set_security_status()
	//...and display them.
	add_to_all_human_data_huds()


/mob/living/carbon/human/get_status_tab_items()
	. = ..()
	. += "Intent: [a_intent]"
	. += "Move Mode: [m_intent]"
	if (internal)
		if (!internal.air_contents)
			qdel(internal)
		else
			. += ""
			. += "Internal Atmosphere Info: [internal.name]"
			. += "Tank Pressure: [internal.air_contents.return_pressure()]"
			. += "Distribution Pressure: [internal.distribute_pressure]"

	var/datum/antagonist/hivemind/hivemind = mind.has_antag_datum(/datum/antagonist/hivemind)
	if(hivemind)
		. += ""
		. += "Hivemind Vessels: [hivemind.hive_size] (+[hivemind.size_mod])"
		. += "Psychic Link Duration: [(hivemind.track_bonus + TRACKER_DEFAULT_TIME)/10] seconds"

	if(mind)
		var/datum/antagonist/changeling/changeling = mind.has_antag_datum(/datum/antagonist/changeling)
		if(changeling)
			. += ""
			. += "Chemical Storage: [changeling.chem_charges]/[changeling.chem_storage]"
			. += "Absorbed DNA: [changeling.absorbedcount]"
		var/datum/antagonist/zombie/zombie = mind.has_antag_datum(/datum/antagonist/zombie)
		if(zombie)
			if((zombie.evolutionTime - world.time) > 0)
				. += "Time to Tier 2 Evolution: [(zombie.evolutionTime - world.time) / 10] seconds"


	//NINJACODE
	if(istype(wear_suit, /obj/item/clothing/suit/space/space_ninja)) //Only display if actually a ninja.
		var/obj/item/clothing/suit/space/space_ninja/SN = wear_suit
		. += "SpiderOS Status: [SN.s_initialized ? "Initialized" : "Disabled"]"
		. += "Current Time: [station_time_timestamp()]"
		if(SN.s_initialized)
			//Suit gear
			. += "Energy Charge: [round(SN.cell.charge/100)]%"
			. += "Smoke Bombs: \Roman [SN.s_bombs]"
			//Ninja status
			. += "Fingerprints: [md5(dna.uni_identity)]"
			. += "Unique Identity: [dna.unique_enzymes]"
			. += "Overall Status: [stat > 1 ? "dead" : "[health]% healthy"]"
			. += "Nutrition Status: [nutrition]"
			. += "Oxygen Loss: [getOxyLoss()]"
			. += "Toxin Levels: [getToxLoss()]"
			. += "Burn Severity: [getFireLoss()]"
			. += "Brute Trauma: [getBruteLoss()]"
			. += "Radiation Levels: [radiation] rad"
			. += "Body Temperature: [bodytemperature-T0C] degrees C ([bodytemperature*1.8-459.67] degrees F)"

			//Diseases
			if(length(diseases))
				. += "Viruses:"
				for(var/thing in diseases)
					var/datum/disease/D = thing
					. += "* [D.name], Type: [D.spread_text], Stage: [D.stage]/[D.max_stages], Possible Cure: [D.cure_text]"


/mob/living/carbon/human/show_inv(mob/user)
	user.set_machine(src)
	var/has_breathable_mask = istype(wear_mask, /obj/item/clothing/mask)
	var/list/obscured = check_obscured_slots()
	var/list/dat = list()

	dat += "<table>"
	for(var/i in 1 to held_items.len)
		var/obj/item/I = get_item_for_held_index(i)
		dat += "<tr><td><B>[get_held_index_name(i)]:</B></td><td><A href='?src=[REF(src)];item=[SLOT_HANDS];hand_index=[i]'>[(I && !(I.item_flags & ABSTRACT)) ? I : "<font color=grey>Empty</font>"]</a></td></tr>"
	dat += "<tr><td>&nbsp;</td></tr>"

	dat += "<tr><td><B>Back:</B></td><td><A href='?src=[REF(src)];item=[SLOT_BACK]'>[(back && !(back.item_flags & ABSTRACT)) ? back : "<font color=grey>Empty</font>"]</A>"
	if(has_breathable_mask && istype(back, /obj/item/tank))
		dat += "&nbsp;<A href='?src=[REF(src)];internal=[SLOT_BACK]'>[internal ? "Disable Internals" : "Set Internals"]</A>"

	dat += "</td></tr><tr><td>&nbsp;</td></tr>"

	dat += "<tr><td><B>Head:</B></td><td><A href='?src=[REF(src)];item=[SLOT_HEAD]'>[(head && !(head.item_flags & ABSTRACT)) ? head : "<font color=grey>Empty</font>"]</A></td></tr>"

	if(SLOT_WEAR_MASK in obscured)
		dat += "<tr><td><font color=grey><B>Mask:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Mask:</B></td><td><A href='?src=[REF(src)];item=[SLOT_WEAR_MASK]'>[(wear_mask && !(wear_mask.item_flags & ABSTRACT)) ? wear_mask : "<font color=grey>Empty</font>"]</A></td></tr>"

	if(SLOT_NECK in obscured)
		dat += "<tr><td><font color=grey><B>Neck:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Neck:</B></td><td><A href='?src=[REF(src)];item=[SLOT_NECK]'>[(wear_neck && !(wear_neck.item_flags & ABSTRACT)) ? wear_neck : "<font color=grey>Empty</font>"]</A></td></tr>"

	if(SLOT_GLASSES in obscured)
		dat += "<tr><td><font color=grey><B>Eyes:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Eyes:</B></td><td><A href='?src=[REF(src)];item=[SLOT_GLASSES]'>[(glasses && !(glasses.item_flags & ABSTRACT))	? glasses : "<font color=grey>Empty</font>"]</A></td></tr>"

	if(SLOT_EARS in obscured)
		dat += "<tr><td><font color=grey><B>Ears:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Ears:</B></td><td><A href='?src=[REF(src)];item=[SLOT_EARS]'>[(ears && !(ears.item_flags & ABSTRACT))		? ears		: "<font color=grey>Empty</font>"]</A></td></tr>"

	dat += "<tr><td>&nbsp;</td></tr>"

	dat += "<tr><td><B>Exosuit:</B></td><td><A href='?src=[REF(src)];item=[SLOT_WEAR_SUIT]'>[(wear_suit && !(wear_suit.item_flags & ABSTRACT)) ? wear_suit : "<font color=grey>Empty</font>"]</A></td></tr>"
	if(wear_suit)
		if(SLOT_S_STORE in obscured)
			dat += "<tr><td><font color=grey>&nbsp;&#8627;<B>Suit Storage:</B></font></td></tr>"
		else
			dat += "<tr><td>&nbsp;&#8627;<B>Suit Storage:</B></td><td><A href='?src=[REF(src)];item=[SLOT_S_STORE]'>[(s_store && !(s_store.item_flags & ABSTRACT)) ? s_store : "<font color=grey>Empty</font>"]</A>"
			if(has_breathable_mask && istype(s_store, /obj/item/tank))
				dat += "&nbsp;<A href='?src=[REF(src)];internal=[SLOT_S_STORE]'>[internal ? "Disable Internals" : "Set Internals"]</A>"
			dat += "</td></tr>"
	else
		dat += "<tr><td><font color=grey>&nbsp;&#8627;<B>Suit Storage:</B></font></td></tr>"

	if(SLOT_SHOES in obscured)
		dat += "<tr><td><font color=grey><B>Shoes:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Shoes:</B></td><td><A href='?src=[REF(src)];item=[SLOT_SHOES]'>[(shoes && !(shoes.item_flags & ABSTRACT))		? shoes		: "<font color=grey>Empty</font>"]</A></td></tr>"

	if(SLOT_GLOVES in obscured)
		dat += "<tr><td><font color=grey><B>Gloves:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Gloves:</B></td><td><A href='?src=[REF(src)];item=[SLOT_GLOVES]'>[(gloves && !(gloves.item_flags & ABSTRACT))		? gloves	: "<font color=grey>Empty</font>"]</A></td></tr>"

	if(SLOT_W_UNIFORM in obscured)
		dat += "<tr><td><font color=grey><B>Uniform:</B></font></td><td><font color=grey>Obscured</font></td></tr>"
	else
		dat += "<tr><td><B>Uniform:</B></td><td><A href='?src=[REF(src)];item=[SLOT_W_UNIFORM]'>[(w_uniform && !(w_uniform.item_flags & ABSTRACT)) ? w_uniform : "<font color=grey>Empty</font>"]</A></td></tr>"

	if((w_uniform == null && !(dna && dna.species.nojumpsuit)) || (SLOT_W_UNIFORM in obscured))
		dat += "<tr><td><font color=grey>&nbsp;&#8627;<B>Pockets:</B></font></td></tr>"
		dat += "<tr><td><font color=grey>&nbsp;&#8627;<B>ID:</B></font></td></tr>"
		dat += "<tr><td><font color=grey>&nbsp;&#8627;<B>Belt:</B></font></td></tr>"
	else
		dat += "<tr><td>&nbsp;&#8627;<B>Belt:</B></td><td><A href='?src=[REF(src)];item=[SLOT_BELT]'>[(belt && !(belt.item_flags & ABSTRACT)) ? belt : "<font color=grey>Empty</font>"]</A>"
		if(has_breathable_mask && istype(belt, /obj/item/tank))
			dat += "&nbsp;<A href='?src=[REF(src)];internal=[SLOT_BELT]'>[internal ? "Disable Internals" : "Set Internals"]</A>"
		dat += "</td></tr>"
		dat += "<tr><td>&nbsp;&#8627;<B>Pockets:</B></td><td><A href='?src=[REF(src)];pockets=left'>[(l_store && !(l_store.item_flags & ABSTRACT)) ? "Left (Full)" : "<font color=grey>Left (Empty)</font>"]</A>"
		dat += "&nbsp;<A href='?src=[REF(src)];pockets=right'>[(r_store && !(r_store.item_flags & ABSTRACT)) ? "Right (Full)" : "<font color=grey>Right (Empty)</font>"]</A></td></tr>"
		dat += "<tr><td>&nbsp;&#8627;<B>ID:</B></td><td><A href='?src=[REF(src)];item=[SLOT_WEAR_ID]'>[(wear_id && !(wear_id.item_flags & ABSTRACT)) ? wear_id : "<font color=grey>Empty</font>"]</A></td></tr>"

	// yogs start - show bandaged parts
	for (var/obj/item/bodypart/org in bodyparts)
		if (org.bandaged)
			dat += "<tr><td><i>[org.name]</i> wrapped with:</td><td><a href='byond://?src=\ref[src];unwrap=\ref[org.bandaged]'>[org.bandaged]</a></td></tr>"
	// yogs end

	if(handcuffed)
		dat += "<tr><td><B>Handcuffed:</B> <A href='?src=[REF(src)];item=[SLOT_HANDCUFFED]'>Remove</A></td></tr>"
	if(legcuffed)
		dat += "<tr><td><A href='?src=[REF(src)];item=[SLOT_LEGCUFFED]'>Legcuffed</A></td></tr>"

	dat += {"</table>
	<A href='?src=[REF(user)];mach_close=mob[REF(src)]'>Close</A>
	"}

	var/datum/browser/popup = new(user, "mob[REF(src)]", "[src]", 440, 510)
	popup.set_content(dat.Join())
	popup.open()

// called when something steps onto a human
// this could be made more general, but for now just handle mulebot
/mob/living/carbon/human/Crossed(atom/movable/AM)
	var/mob/living/simple_animal/bot/mulebot/MB = AM
	if(istype(MB))
		MB.RunOver(src)

	. = ..()
	spreadFire(AM)

/mob/living/carbon/human/Topic(href, href_list)
	if(href_list["embedded_object"] && usr.canUseTopic(src, BE_CLOSE, NO_DEXTERY))
		var/obj/item/bodypart/L = locate(href_list["embedded_limb"]) in bodyparts
		if(!L)
			return
		var/obj/item/I = locate(href_list["embedded_object"]) in L.embedded_objects
		if(!I || I.loc != src) //no item, no limb, or item is not in limb or in the person anymore
			return
		var/time_taken = I.embedding.embedded_unsafe_removal_time*I.w_class
		usr.visible_message(span_warning("[usr] attempts to remove [I] from [usr.p_their()] [L.name]."),span_notice("You attempt to remove [I] from your [L.name]... (It will take [DisplayTimeText(time_taken)].)"))
		if(do_after(usr, time_taken, needhand = 1, target = src))
			if(!I || !L || I.loc != src || !(I in L.embedded_objects))
				return
			L.embedded_objects -= I
			L.receive_damage(I.embedding.embedded_unsafe_removal_pain_multiplier*I.w_class, sharpness=SHARP_EDGED)//It hurts to rip it out, get surgery you dingus.
			I.forceMove(get_turf(src))
			usr.put_in_hands(I)
			usr.emote("scream")
			usr.visible_message("[usr] successfully rips [I] out of [usr.p_their()] [L.name]!",span_notice("You successfully remove [I] from your [L.name]."))
			if(!has_embedded_objects())
				clear_alert("embeddedobject")
				SEND_SIGNAL(usr, COMSIG_CLEAR_MOOD_EVENT, "embedded")
		return

	if(href_list["item"]) //canUseTopic check for this is handled by mob/Topic()
		var/slot = text2num(href_list["item"])
		if(slot in check_obscured_slots(TRUE))
			to_chat(usr, span_warning("You can't reach that! Something is covering it."))
			return

	if(href_list["pockets"] && usr.canUseTopic(src, BE_CLOSE, NO_DEXTERY)) //TODO: Make it match (or intergrate it into) strippanel so you get 'item cannot fit here' warnings if mob_can_equip fails
		var/pocket_side = href_list["pockets"]
		var/pocket_id = (pocket_side == "right" ? SLOT_R_STORE : SLOT_L_STORE)
		var/obj/item/pocket_item = (pocket_id == SLOT_R_STORE ? r_store : l_store)
		var/obj/item/place_item = usr.get_active_held_item() // Item to place in the pocket, if it's empty

		var/delay_denominator = 1
		if(pocket_item && !(pocket_item.item_flags & ABSTRACT))
			if(HAS_TRAIT(pocket_item, TRAIT_NODROP))
				to_chat(usr, span_warning("You try to empty [src]'s [pocket_side] pocket, it seems to be stuck!"))
			to_chat(usr, span_notice("You try to empty [src]'s [pocket_side] pocket."))
		else if(place_item && place_item.mob_can_equip(src, usr, pocket_id, 1) && !(place_item.item_flags & ABSTRACT))
			to_chat(usr, span_notice("You try to place [place_item] into [src]'s [pocket_side] pocket."))
			delay_denominator = 4
		else
			return

		if(do_mob(usr, src, POCKET_STRIP_DELAY/delay_denominator)) //placing an item into the pocket is 4 times faster
			if(pocket_item)
				if(pocket_item == (pocket_id == SLOT_R_STORE ? r_store : l_store)) //item still in the pocket we search
					dropItemToGround(pocket_item)
			else
				if(place_item)
					if(place_item.mob_can_equip(src, usr, pocket_id, FALSE, TRUE))
						usr.temporarilyRemoveItemFromInventory(place_item, TRUE)
						equip_to_slot(place_item, pocket_id, TRUE)
					//do nothing otherwise
				//updating inv screen after handled by living/Topic()
		else
			// Display a warning if the user mocks up
			to_chat(src, span_warning("You feel your [pocket_side] pocket being fumbled with!"))

///////HUDs///////
	if(href_list["hud"])
		if(ishuman(usr))
			var/mob/living/carbon/human/H = usr
			var/perpname = get_face_name(get_id_name(""))
			if(istype(H.glasses, /obj/item/clothing/glasses/hud) || istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud))
				var/datum/data/record/R = find_record("name", perpname, GLOB.data_core.general)
				if(href_list["photo_front"] || href_list["photo_side"])
					if(R)
						if(!H.canUseHUD())
							return
						else if(!istype(H.glasses, /obj/item/clothing/glasses/hud) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/medical))
							return
						var/obj/item/photo/P = null
						if(href_list["photo_front"])
							P = R.fields["photo_front"]
						else if(href_list["photo_side"])
							P = R.fields["photo_side"]
						if(P)
							P.show(H)

				if(href_list["hud"] == "m")
					if(istype(H.glasses, /obj/item/clothing/glasses/hud/health) || istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/medical))
						if(href_list["p_stat"])
							var/health_status = input(usr, "Specify a new physical status for this person.", "Medical HUD", R.fields["p_stat"]) in list("Active", "Physically Unfit", "*Unconscious*", "*Deceased*", "Cancel")
							if(R)
								if(!H.canUseHUD())
									return
								else if(!istype(H.glasses, /obj/item/clothing/glasses/hud/health) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/medical))
									return
								if(health_status && health_status != "Cancel")
									R.fields["p_stat"] = health_status
							return
						if(href_list["m_stat"])
							var/health_status = input(usr, "Specify a new mental status for this person.", "Medical HUD", R.fields["m_stat"]) in list("Stable", "*Watch*", "*Unstable*", "*Insane*", "Cancel")
							if(R)
								if(!H.canUseHUD())
									return
								else if(!istype(H.glasses, /obj/item/clothing/glasses/hud/health) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/medical))
									return
								if(health_status && health_status != "Cancel")
									R.fields["m_stat"] = health_status
							return
						if(href_list["evaluation"])
							if(!getBruteLoss() && !getFireLoss() && !getOxyLoss() && getToxLoss() < 20)
								to_chat(usr, "[span_notice("No external injuries detected.")]<br>")
								return
							var/span = "notice"
							var/status = ""
							if(getBruteLoss())
								to_chat(usr, "<b>Physical trauma analysis:</b>")
								for(var/X in bodyparts)
									var/obj/item/bodypart/BP = X
									var/brutedamage = BP.brute_dam
									if(brutedamage > 0)
										status = "received minor physical injuries."
										span = "notice"
									if(brutedamage > 20)
										status = "been seriously damaged."
										span = "danger"
									if(brutedamage > 40)
										status = "sustained major trauma!"
										span = "userdanger"
									if(brutedamage)
										to_chat(usr, "<span class='[span]'>[BP] appears to have [status]</span>")
							if(getFireLoss())
								to_chat(usr, "<b>Analysis of skin burns:</b>")
								for(var/X in bodyparts)
									var/obj/item/bodypart/BP = X
									var/burndamage = BP.burn_dam
									if(burndamage > 0)
										status = "signs of minor burns."
										span = "notice"
									if(burndamage > 20)
										status = "serious burns."
										span = "danger"
									if(burndamage > 40)
										status = "major burns!"
										span = "userdanger"
									if(burndamage)
										to_chat(usr, "<span class='[span]'>[BP] appears to have [status]</span>")
							if(getOxyLoss())
								to_chat(usr, span_danger("Patient has signs of suffocation, emergency treatment may be required!"))
							if(getToxLoss() > 20)
								to_chat(usr, span_danger("Gathered data is inconsistent with the analysis, possible cause: poisoning."))

				if(href_list["hud"] == "s")
					if(istype(H.glasses, /obj/item/clothing/glasses/hud/security) || istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/security))
						if(usr.stat || usr == src) //|| !usr.canmove || usr.restrained()) Fluff: Sechuds have eye-tracking technology and sets 'arrest' to people that the wearer looks and blinks at.
							return													  //Non-fluff: This allows sec to set people to arrest as they get disarmed or beaten
						// Checks the user has security clearence before allowing them to change arrest status via hud, comment out to enable all access
						var/allowed_access = null
						var/obj/item/clothing/glasses/hud/security/G = H.glasses
						if(istype(G) && (G.obj_flags & EMAGGED))
							allowed_access = "@%&ERROR_%$*"
						else //Implant and standard glasses check access
							if(H.wear_id)
								var/list/access = H.wear_id.GetAccess()
								if(ACCESS_SEC_DOORS in access)
									allowed_access = H.get_authentification_name()

						if(!allowed_access)
							to_chat(H, span_warning("ERROR: Invalid Access"))
							return

						if(perpname)
							R = find_record("name", perpname, GLOB.data_core.security)
							if(R)
								if(href_list["status"])
									var/setcriminal = input(usr, "Specify a new criminal status for this person.", "Security HUD", R.fields["criminal"]) in list("None", "*Arrest*", "Search", "Incarcerated", "Paroled", "Discharged", "Cancel")
									if(setcriminal != "Cancel")
										if(R)
											if(H.canUseHUD())
												if(istype(H.glasses, /obj/item/clothing/glasses/hud/security) || istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/security))
													investigate_log("[key_name(src)] has been set from [R.fields["criminal"]] to [setcriminal] by [key_name(usr)].", INVESTIGATE_RECORDS)
													R.fields["criminal"] = setcriminal
													sec_hud_set_security_status()
									return

								if(href_list["view"])
									if(R)
										if(!H.canUseHUD())
											return
										else if(!istype(H.glasses, /obj/item/clothing/glasses/hud/security) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/security))
											return
										to_chat(usr, "<b>Name:</b> [R.fields["name"]]	<b>Criminal Status:</b> [R.fields["criminal"]]")
										to_chat(usr, "<b>Crimes:</b>")
										for(var/datum/data/crime/c in R.fields["crimes"])
											to_chat(usr, "<b>Crime:</b> [c.crimeName]")
											to_chat(usr, "<b>Details:</b> [c.crimeDetails]")
											to_chat(usr, "Added by [c.author] at [c.time]")
											to_chat(usr, "----------")
										to_chat(usr, "<b>Comments:</b>")
										for(var/datum/data/comment/c in R.fields["comments"])
											to_chat(usr, "<b>Comment:</b> [c.commentText]")
											to_chat(usr, "Added by [c.author] at [c.time]")
											to_chat(usr, "----------")
										to_chat(usr, "<b>Notes:</b> [R.fields["notes"]]")
									return

								if(href_list["add_crime"])
									if(R)
										var/crimeName = stripped_input("Please input crime name:", "Security HUD", "")
										var/crimeDetails = stripped_multiline_input("Please input crime details:", "Security HUD", "")
										if(R)
											if (!crimeName || !crimeDetails || !allowed_access)
												return
											else if(!H.canUseHUD())
												return
											else if(!istype(H.glasses, /obj/item/clothing/glasses/hud/security) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/security))
												return
											var/crime = GLOB.data_core.createCrimeEntry(crimeName, crimeDetails, allowed_access, station_time_timestamp())
											GLOB.data_core.addCrime(R.fields["id"], crime)
											investigate_log("New Crime: <strong>[crimeName]</strong>: [crimeDetails] | Added to [R.fields["name"]] by [key_name(usr)]", INVESTIGATE_RECORDS)
											to_chat(usr, span_notice("Successfully added a crime."))
									return

								if(href_list["view_comment"])
									if(R)
										if(!H.canUseHUD())
											return
										else if(!istype(H.glasses, /obj/item/clothing/glasses/hud/security) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/security))
											return
										to_chat(usr, "<b>Comments/Log:</b>")
										for(var/datum/data/comment/C in R.fields["comments"])
											to_chat(usr, text("Made by [] on []<BR>[]", C.author, C.time, C.commentText))
											to_chat(usr, "----------")
										return

								if(href_list["add_comment"])
									if(R)
										var/commentValue = stripped_multiline_input("Add Comment:", "Security records")
										if(R)
											if (!commentValue || !allowed_access)
												return
											else if(!H.canUseHUD())
												return
											else if(!istype(H.glasses, /obj/item/clothing/glasses/hud/security) && !istype(H.getorganslot(ORGAN_SLOT_HUD), /obj/item/organ/cyberimp/eyes/hud/security))
												return
											var/comment = GLOB.data_core.createCommentEntry(commentValue, allowed_access)
											GLOB.data_core.addComment(R.fields["id"], comment)
											to_chat(usr, span_notice("Successfully added comment."))
											return
							to_chat(usr, span_warning("Unable to locate a data core entry for this person."))

	..() //end of this massive fucking chain. TODO: make the hud chain not spooky.


/mob/living/carbon/human/proc/canUseHUD()
	return (mobility_flags & MOBILITY_USE)

/mob/living/carbon/human/can_inject(mob/user, error_msg, target_zone, var/penetrate_thick = 0)
	. = 1 // Default to returning true.
	if(user && !target_zone)
		target_zone = user.zone_selected
	if(HAS_TRAIT(src, TRAIT_PIERCEIMMUNE))
		. = 0
	// If targeting the head, see if the head item is thin enough.
	// If targeting anything else, see if the wear suit is thin enough.
	if (!penetrate_thick)
		if(above_neck(target_zone))
			if(head && istype(head, /obj/item/clothing))
				var/obj/item/clothing/CH = head
				if (CH.clothing_flags & THICKMATERIAL)
					. = 0
		else
			if(wear_suit && istype(wear_suit, /obj/item/clothing))
				var/obj/item/clothing/CS = wear_suit
				if (CS.clothing_flags & THICKMATERIAL)
					. = 0
	if(!. && error_msg && user)
		// Might need re-wording.
		to_chat(user, span_alert("There is no exposed flesh or thin material [above_neck(target_zone) ? "on [p_their()] head" : "on [p_their()] body"]."))

/mob/living/carbon/human/assess_threat(judgement_criteria, lasercolor = "", datum/callback/weaponcheck=null)
	if(judgement_criteria & JUDGE_EMAGGED)
		return 10 //Everyone is a criminal!

	var/threatcount = 0

	//Lasertag bullshit
	if(lasercolor)
		if(lasercolor == "b")//Lasertag turrets target the opposing team, how great is that? -Sieve
			if(istype(wear_suit, /obj/item/clothing/suit/redtag))
				threatcount += 4
			if(is_holding_item_of_type(/obj/item/gun/energy/laser/redtag))
				threatcount += 4
			if(istype(belt, /obj/item/gun/energy/laser/redtag))
				threatcount += 2

		if(lasercolor == "r")
			if(istype(wear_suit, /obj/item/clothing/suit/bluetag))
				threatcount += 4
			if(is_holding_item_of_type(/obj/item/gun/energy/laser/bluetag))
				threatcount += 4
			if(istype(belt, /obj/item/gun/energy/laser/bluetag))
				threatcount += 2

		return threatcount

	//Check for ID
	var/obj/item/card/id/idcard = get_idcard(FALSE)
	if( (judgement_criteria & JUDGE_IDCHECK) && !idcard && name=="Unknown")
		threatcount += 4

	//Check for weapons
	if( (judgement_criteria & JUDGE_WEAPONCHECK) && weaponcheck)
		if(!idcard || !(ACCESS_WEAPONS in idcard.access))
			for(var/obj/item/I in held_items) //if they're holding a gun
				if(weaponcheck.Invoke(I))
					threatcount += 4
			if(weaponcheck.Invoke(belt) || weaponcheck.Invoke(back)) //if a weapon is present in the belt or back slot
				threatcount += 2 //not enough to trigger look_for_perp() on it's own unless they also have criminal status.

	//Check for arrest warrant
	if(judgement_criteria & JUDGE_RECORDCHECK)
		var/perpname = get_face_name(get_id_name())
		var/datum/data/record/R = find_record("name", perpname, GLOB.data_core.security)
		if(R && R.fields["criminal"])
			switch(R.fields["criminal"])
				if("*Arrest*")
					threatcount += 5
				if("Incarcerated")
					threatcount += 2
				if("Paroled")
					threatcount += 2

	//Check for dresscode violations
	if(istype(head, /obj/item/clothing/head/wizard) || istype(head, /obj/item/clothing/head/helmet/space/hardsuit/wizard))
		threatcount += 2

	//Check for nonhuman scum
	if(dna && dna.species.id && dna.species.id != "human")
		threatcount += 1

	//mindshield implants imply trustworthyness
	if(HAS_TRAIT(src, TRAIT_MINDSHIELD))
		threatcount -= 1

	//Agent cards lower threatlevel.
	if(istype(idcard, /obj/item/card/id/syndicate))
		threatcount -= 5

	return threatcount


//Used for new human mobs created by cloning/goleming/podding
/mob/living/carbon/human/proc/set_cloned_appearance()
	if(gender == MALE)
		facial_hair_style = "Full Beard"
	else
		facial_hair_style = "Shaved"
	hair_style = pick("Bedhead", "Bedhead 2", "Bedhead 3")
	underwear = "Nude"
	update_body()
	update_hair()

/mob/living/carbon/human/singularity_pull(S, current_size)
	..()
	if(current_size >= STAGE_THREE)
		for(var/obj/item/hand in held_items)
			if(prob(current_size * 5) && hand.w_class >= ((11-current_size)/2)  && dropItemToGround(hand))
				step_towards(hand, src)
				to_chat(src, span_warning("\The [S] pulls \the [hand] from your grip!"))
	rad_act(current_size * 3)

/mob/living/carbon/human/proc/do_cpr(mob/living/carbon/C)
	CHECK_DNA_AND_SPECIES(C)

	if(C.stat == DEAD || (HAS_TRAIT(C, TRAIT_FAKEDEATH)))
		to_chat(src, span_warning("[C.name] is dead!"))
		return
	if(is_mouth_covered())
		to_chat(src, span_warning("Remove your mask first!"))
		return 0
	if(C.is_mouth_covered())
		to_chat(src, span_warning("Remove [p_their()] mask first!"))
		return 0

	if(C.cpr_time < world.time + 30)
		visible_message(span_notice("[src] is trying to perform CPR on [C.name]!"), \
						span_notice("You try to perform CPR on [C.name]... Hold still!"))
		if(!do_mob(src, C))
			to_chat(src, span_warning("You fail to perform CPR on [C]!"))
			return 0

		var/they_breathe = !HAS_TRAIT(C, TRAIT_NOBREATH)
		var/they_lung = C.getorganslot(ORGAN_SLOT_LUNGS)
		var/they_ashlung = C.getorgan(/obj/item/organ/lungs/ashwalker) // yogs - Do they have ashwalker lungs?
		var/we_ashlung = getorgan(/obj/item/organ/lungs/ashwalker) // yogs - Does the guy doing CPR have ashwalker lungs?

		if(C.health > C.crit_threshold)
			return

		src.visible_message("[src] performs CPR on [C.name]!", span_notice("You perform CPR on [C.name]."))
		SEND_SIGNAL(src, COMSIG_ADD_MOOD_EVENT, "perform_cpr", /datum/mood_event/perform_cpr)
		C.cpr_time = world.time
		log_combat(src, C, "CPRed")
		SSachievements.unlock_achievement(/datum/achievement/cpr, client)
		// yogs start - can't CPR people with ash walker lungs whithout having them yourself
		if(they_breathe && !!they_ashlung != !!we_ashlung)
			C.adjustOxyLoss(10)
			C.updatehealth()
			to_chat(C, "<span class='unconscious'>You feel a breath of fresh air enter your lungs... you feel worse...")
			SSachievements.unlock_achievement(/datum/achievement/anticpr, client) //you can get both achievements at the same time I guess
		//yogs end
		else if(they_breathe && they_lung)
			var/suff = min(C.getOxyLoss(), 7)
			C.adjustOxyLoss(-suff)
			C.updatehealth()
			to_chat(C, span_unconscious("You feel a breath of fresh air enter your lungs... It feels good..."))
		else if(they_breathe && !they_lung)
			to_chat(C, span_unconscious("You feel a breath of fresh air... but you don't feel any better..."))
		else
			to_chat(C, span_unconscious("You feel a breath of fresh air... which is a sensation you don't recognise..."))

/mob/living/carbon/human/cuff_resist(obj/item/I)
	if(dna && (dna.check_mutation(HULK) || dna.check_mutation(ACTIVE_HULK)))
		say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ), forced = "hulk")
		if(..(I, cuff_break = FAST_CUFFBREAK))
			dropItemToGround(I)
	else
		if(..())
			dropItemToGround(I)

/**
  * Wash the hands, cleaning either the gloves if equipped and not obscured, otherwise the hands themselves if they're not obscured.
  *
  * Returns false if we couldn't wash our hands due to them being obscured, otherwise true
  */
/mob/living/carbon/human/proc/wash_hands(clean_types)
	var/list/obscured = check_obscured_slots()
	if(ITEM_SLOT_GLOVES in obscured)
		return FALSE
	if(gloves)
		if(gloves.wash(clean_types))
			update_inv_gloves()
	else if((clean_types & CLEAN_TYPE_BLOOD) && blood_in_hands > 0)
		blood_in_hands = 0
		update_inv_gloves()

	return TRUE

/**
  * Cleans the lips of any lipstick. Returns TRUE if the lips had any lipstick and was thus cleaned
  */
/mob/living/carbon/human/proc/clean_lips()
	if(isnull(lip_style) && lip_color == initial(lip_color))
		return FALSE
	lip_style = null
	lip_color = initial(lip_color)
	update_body()
	return TRUE

/**
  * Called on the COMSIG_COMPONENT_CLEAN_FACE_ACT signal
  */
/mob/living/carbon/human/proc/clean_face(datum/source, clean_types)
	grad_color = dna.features["gradientcolor"]
	grad_style = dna.features["gradientstyle"]
	update_hair()

	if(!is_mouth_covered() && clean_lips())
		. = TRUE

	if(glasses && is_eyes_covered(FALSE, TRUE, TRUE) && glasses.wash(clean_types))
		update_inv_glasses()
		. = TRUE

	var/list/obscured = check_obscured_slots()
	if(wear_mask && !(ITEM_SLOT_MASK in obscured) && wear_mask.wash(clean_types))
		update_inv_wear_mask()
		. = TRUE

/**
  * Called when this human should be washed
  */
/mob/living/carbon/human/wash(clean_types)
	. = ..()

	// Wash equipped stuff that cannot be covered
	if(wear_suit?.wash(clean_types))
		update_inv_wear_suit()
		. = TRUE

	if(belt?.wash(clean_types))
		update_inv_belt()
		. = TRUE

	// Check and wash stuff that can be covered
	var/list/obscured = check_obscured_slots()

	if(w_uniform && !(ITEM_SLOT_ICLOTHING in obscured) && w_uniform.wash(clean_types))
		update_inv_w_uniform()
		. = TRUE

	if(!is_mouth_covered() && clean_lips())
		. = TRUE

	// Wash hands if exposed
	if(!gloves && (clean_types & CLEAN_TYPE_BLOOD) && blood_in_hands > 0 && !(ITEM_SLOT_GLOVES in obscured))
		blood_in_hands = 0
		update_inv_gloves()
		. = TRUE
	wash_cream()

/mob/living/carbon/human/wash_cream()
	if(creamed) //clean both to prevent a rare bug
		cut_overlay(mutable_appearance('icons/effects/creampie.dmi', "creampie_lizard"))
		cut_overlay(mutable_appearance('icons/effects/creampie.dmi', "creampie_human"))
		creamed = FALSE

//Turns a mob black, flashes a skeleton overlay
//Just like a cartoon!
/mob/living/carbon/human/proc/electrocution_animation(anim_duration)
	//Handle mutant parts if possible
	if(dna && dna.species)
		add_atom_colour("#000000", TEMPORARY_COLOUR_PRIORITY)
		var/static/mutable_appearance/electrocution_skeleton_anim
		if(!electrocution_skeleton_anim)
			electrocution_skeleton_anim = mutable_appearance(icon, "electrocuted_base")
			electrocution_skeleton_anim.appearance_flags |= RESET_COLOR|KEEP_APART
		add_overlay(electrocution_skeleton_anim)
		addtimer(CALLBACK(src, .proc/end_electrocution_animation, electrocution_skeleton_anim), anim_duration)

	else //or just do a generic animation
		flick_overlay_view(image(icon,src,"electrocuted_generic",ABOVE_MOB_LAYER), src, anim_duration)

/mob/living/carbon/human/proc/end_electrocution_animation(mutable_appearance/MA)
	remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, "#000000")
	cut_overlay(MA)

/mob/living/carbon/human/canUseTopic(atom/movable/M, be_close=FALSE, no_dextery=FALSE, no_tk=FALSE)
	if(!(mobility_flags & MOBILITY_UI))
		to_chat(src, span_warning("You can't do that right now!"))
		return FALSE
	if(!Adjacent(M) && (M.loc != src))
		if((be_close == FALSE) || (!no_tk && (dna.check_mutation(TK) && tkMaxRangeCheck(src, M))))
			return TRUE
		to_chat(src, span_warning("You are too far away!"))
		return FALSE
	return TRUE

/mob/living/carbon/human/resist_restraints()
	if(wear_suit && wear_suit.breakouttime)
		changeNext_move(CLICK_CD_BREAKOUT)
		last_special = world.time + CLICK_CD_BREAKOUT
		cuff_resist(wear_suit)
	else
		..()

/mob/living/carbon/human/replace_records_name(oldname,newname) // Only humans have records right now, move this up if changed.
	for(var/list/L in list(GLOB.data_core.general,GLOB.data_core.medical,GLOB.data_core.security,GLOB.data_core.locked))
		var/datum/data/record/R = find_record("name", oldname, L)
		if(R)
			R.fields["name"] = newname

/mob/living/carbon/human/get_total_tint()
	. = ..()
	if(glasses)
		. += glasses.tint

/mob/living/carbon/human/update_health_hud()
	if(!client || !hud_used)
		return
	if(dna.species.update_health_hud())
		return
	else
		if(hud_used.healths)
			var/health_amount = min(health, maxHealth - getStaminaLoss())
			if(..(health_amount)) //not dead
				switch(hal_screwyhud)
					if(SCREWYHUD_CRIT)
						hud_used.healths.icon_state = "health6"
					if(SCREWYHUD_DEAD)
						hud_used.healths.icon_state = "health7"
					if(SCREWYHUD_HEALTHY)
						hud_used.healths.icon_state = "health0"
		if(hud_used.healthdoll)
			hud_used.healthdoll.cut_overlays()
			if(stat != DEAD)
				hud_used.healthdoll.icon_state = "healthdoll_OVERLAY"
				for(var/X in bodyparts)
					var/obj/item/bodypart/BP = X
					var/damage = BP.burn_dam + BP.brute_dam
					var/comparison = (BP.max_damage/5)
					var/icon_num = 0
					if(damage)
						icon_num = 1
					if(damage > (comparison))
						icon_num = 2
					if(damage > (comparison*2))
						icon_num = 3
					if(damage > (comparison*3))
						icon_num = 4
					if(damage > (comparison*4))
						icon_num = 5
					if(hal_screwyhud == SCREWYHUD_HEALTHY)
						icon_num = 0
					if(icon_num)
						hud_used.healthdoll.add_overlay(mutable_appearance('icons/mob/screen_gen.dmi', "[BP.body_zone][icon_num]"))
				for(var/t in get_missing_limbs()) //Missing limbs
					hud_used.healthdoll.add_overlay(mutable_appearance('icons/mob/screen_gen.dmi', "[t]6"))
				for(var/t in get_disabled_limbs()) //Disabled limbs
					hud_used.healthdoll.add_overlay(mutable_appearance('icons/mob/screen_gen.dmi', "[t]7"))
			else
				hud_used.healthdoll.icon_state = "healthdoll_DEAD"

/mob/living/carbon/human/fully_heal(admin_revive = 0)
	dna?.species.spec_fully_heal(src)
	if(admin_revive)
		regenerate_limbs()
		regenerate_organs()
	remove_all_embedded_objects()
	set_heartattack(FALSE)
	drunkenness = 0
	for(var/datum/mutation/human/HM in dna.mutations)
		if(HM.quality != POSITIVE)
			dna.remove_mutation(HM.name)
	..()

/mob/living/carbon/human/check_weakness(obj/item/weapon, mob/living/attacker)
	. = ..()
	if (dna && dna.species)
		. += dna.species.check_species_weakness(weapon, attacker)

/mob/living/carbon/human/is_literate()
	return TRUE

/mob/living/carbon/human/can_hold_items()
	return TRUE

/mob/living/carbon/human/update_gravity(has_gravity,override = 0)
	if(dna && dna.species) //prevents a runtime while a human is being monkeyfied
		override = dna.species.override_float
	..()

/mob/living/carbon/human/vomit(lost_nutrition = 10, blood = 0, stun = 1, distance = 0, message = 1, toxic = 0)
	if(blood && (NOBLOOD in dna.species.species_traits))
		if(message)
			visible_message(span_warning("[src] dry heaves!"), \
							span_userdanger("You try to throw up, but there's nothing in your stomach!"))
		if(stun)
			Paralyze(200)
		return 1
	..()

/mob/living/carbon/human/vv_get_dropdown()
	. = ..()
	. += "---"
	.["Make monkey"] = "?_src_=vars;[HrefToken()];makemonkey=[REF(src)]"
	.["Set Species"] = "?_src_=vars;[HrefToken()];setspecies=[REF(src)]"
	.["Make cyborg"] = "?_src_=vars;[HrefToken()];makerobot=[REF(src)]"
	.["Make alien"] = "?_src_=vars;[HrefToken()];makealien=[REF(src)]"
	.["Make slime"] = "?_src_=vars;[HrefToken()];makeslime=[REF(src)]"
	.["Toggle Purrbation"] = "?_src_=vars;[HrefToken()];purrbation=[REF(src)]"
	.["Copy outfit"] = "?_src_=vars;[HrefToken()];copyoutfit=[REF(src)]"
	.["Add/Remove Quirks"] = "?_src_=vars;[HrefToken()];modquirks=[REF(src)]"
	.["Make Cluwne"] = "?_src_=vars;[HrefToken()];cluwneing=[REF(src)]" // yogs -- make cluwne
	.["Make Pacman"] = "?_src_=vars;[HrefToken()];makepacman=[REF(src)]" //I LOVE PACMAN

/mob/living/carbon/human/MouseDrop_T(mob/living/target, mob/living/user)
	if(pulling == target && grab_state >= GRAB_AGGRESSIVE && stat == CONSCIOUS)
		//If they dragged themselves and we're currently aggressively grabbing them try to piggyback
		if(user == target && can_piggyback(target))
			piggyback(target)
			return
		//If you dragged them to you and you're aggressively grabbing try to fireman carry them
		else if(user != target && user.a_intent == INTENT_GRAB && can_be_firemanned(target))
			fireman_carry(target)
			return
	. = ..()

//src is the user that will be carrying, target is the mob to be carried
/mob/living/carbon/human/proc/can_piggyback(mob/living/carbon/target)
	return (istype(target) && target.stat == CONSCIOUS)

/mob/living/carbon/human/proc/can_be_firemanned(mob/living/carbon/target)
	return (ishuman(target) && !(target.mobility_flags & MOBILITY_STAND))

/mob/living/carbon/human/proc/fireman_carry(mob/living/carbon/target)
	var/carrydelay = 50 //if you have latex you are faster at grabbing
	var/skills_space = "" // Changes depending on glove type
	if(HAS_TRAIT(src, TRAIT_QUICKER_CARRY))
		carrydelay = 30
		skills_space = "expertly"
	else if(HAS_TRAIT(src, TRAIT_QUICK_CARRY))
		carrydelay = 40
		skills_space = "quickly"
	if(can_be_firemanned(target) && !incapacitated(FALSE, TRUE))
		visible_message(span_notice("[src] starts [skills_space] lifting [target] onto their back.."),
		//Joe Medic starts quickly/expertly lifting Grey Tider onto their back..
		span_notice("[carrydelay < 35 ? "Using your gloves' nanochips, you" : "You"] [skills_space] start to lift [target] onto your back[carrydelay == 40 ? ", while assisted by the nanochips in your gloves.." : "..."]"))
		//(Using your gloves' nanochips, you/You) ( /quickly/expertly) start to lift Grey Tider onto your back(, while assisted by the nanochips in your gloves../...)
		if(do_after(src, carrydelay, TRUE, target))
			//Second check to make sure they're still valid to be carried
			if(can_be_firemanned(target) && !incapacitated(FALSE, TRUE) && !target.buckled)
				if(target.loc != loc)
					var/old_density = density
					density = FALSE
					step_towards(target, loc)
					density = old_density
					if(target.loc == loc)
						buckle_mob(target, TRUE, TRUE, 90, 1, 0)
						return
				else
					buckle_mob(target, TRUE, TRUE, 90, 1, 0)
		visible_message(span_warning("[src] fails to fireman carry [target]!"))
	else
		to_chat(src, span_warning("You can't fireman carry [target] while they're standing!"))

/mob/living/carbon/human/proc/piggyback(mob/living/carbon/target)
	if(can_piggyback(target))
		visible_message(span_notice("[target] starts to climb onto [src]..."))
		if(do_after(target, 3 SECONDS, target = src))
			if(can_piggyback(target))
				if(target.incapacitated(FALSE, TRUE) || incapacitated(FALSE, TRUE))
					target.visible_message(span_warning("[target] can't hang onto [src]!"))
					return
				buckle_mob(target, TRUE, TRUE, FALSE, 0, 2)
		else
			visible_message(span_warning("[target] fails to climb onto [src]!"))
	else
		to_chat(target, span_warning("You can't piggyback ride [src] right now!"))

/mob/living/carbon/human/buckle_mob(mob/living/target, force = FALSE, check_loc = TRUE, lying_buckle = FALSE, hands_needed = 0, target_hands_needed = 0)
	if(!force)//humans are only meant to be ridden through piggybacking and special cases
		return
	if(!is_type_in_typecache(target, can_ride_typecache))
		target.visible_message(span_warning("[target] really can't seem to mount [src]..."))
		return
	buckle_lying = lying_buckle
	var/datum/component/riding/human/riding_datum = LoadComponent(/datum/component/riding/human)
	if(target_hands_needed)
		riding_datum.ride_check_rider_restrained = TRUE
	if(buckled_mobs && ((target in buckled_mobs) || (buckled_mobs.len >= max_buckled_mobs)) || buckled)
		return
	var/equipped_hands_self
	var/equipped_hands_target
	if(hands_needed)
		equipped_hands_self = riding_datum.equip_buckle_inhands(src, hands_needed, target)
	if(target_hands_needed)
		equipped_hands_target = riding_datum.equip_buckle_inhands(target, target_hands_needed)

	if(hands_needed || target_hands_needed)
		if(hands_needed && !equipped_hands_self)
			src.visible_message(span_warning("[src] can't get a grip on [target] because their hands are full!"),
				span_warning("You can't get a grip on [target] because your hands are full!"))
			return
		else if(target_hands_needed && !equipped_hands_target)
			target.visible_message(span_warning("[target] can't get a grip on [src] because their hands are full!"),
				span_warning("You can't get a grip on [src] because your hands are full!"))
			return

	stop_pulling()
	riding_datum.handle_vehicle_layer()
	. = ..(target, force, check_loc)

/mob/living/carbon/human/proc/is_shove_knockdown_blocked() //If you want to add more things that block shove knockdown, extend this
	var/list/body_parts = list(head, wear_mask, wear_suit, w_uniform, back, gloves, shoes, belt, s_store, glasses, ears, wear_id) //Everything but pockets. Pockets are l_store and r_store. (if pockets were allowed, putting something armored, gloves or hats for example, would double up on the armor)
	for(var/bp in body_parts)
		if(istype(bp, /obj/item/clothing))
			var/obj/item/clothing/C = bp
			if(C.blocks_shove_knockdown)
				return TRUE
	return FALSE

/mob/living/carbon/human/proc/clear_shove_slowdown()
	remove_movespeed_modifier(MOVESPEED_ID_SHOVE)
	var/active_item = get_active_held_item()
	if(is_type_in_typecache(active_item, GLOB.shove_disarming_types))
		visible_message(span_warning("[src.name] regains their grip on \the [active_item]!"), span_warning("You regain your grip on \the [active_item]"), null, COMBAT_MESSAGE_RANGE)

/mob/living/carbon/human/do_after_coefficent()
	. = ..()
	. *= physiology.do_after_speed

/mob/living/carbon/human/updatehealth()
	var/oldhealth = health
	. = ..()
	dna?.species.spec_updatehealth(src)
	if(!dna)
		return
	hulk_health_check(oldhealth)

/mob/living/carbon/human/adjust_nutrition(var/change) //Honestly FUCK the oldcoders for putting nutrition on /mob someone else can move it up because holy hell I'd have to fix SO many typechecks
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/set_nutrition(var/change) //Seriously fuck you oldcoders.
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/proc/play_xylophone()
	if(!src.xylophone)
		visible_message("\red [src] begins playing his ribcage like a xylophone. It's quite spooky.","\blue You begin to play a spooky refrain on your ribcage.","\red You hear a spooky xylophone melody.")
		var/song = pick('sound/effects/xylophone1.ogg','sound/effects/xylophone2.ogg','sound/effects/xylophone3.ogg')
		playsound(loc, song, 50, 1, -1)
		xylophone = 1
		spawn(600)
			xylophone=0
	return

/mob/living/carbon/human/is_bleeding()
	if(NOBLOOD in dna.species.species_traits || bleedsuppress)
		return FALSE
	return ..()

/mob/living/carbon/human/get_total_bleed_rate()
	if(NOBLOOD in dna.species.species_traits)
		return FALSE
	return ..()

/mob/living/carbon/human/species
	var/race = null

/mob/living/carbon/human/species/Initialize()
	. = ..()
	set_species(race)

/mob/living/carbon/human/species/abductor
	race = /datum/species/abductor

/mob/living/carbon/human/species/android
	race = /datum/species/android

/mob/living/carbon/human/species/corporate
	race = /datum/species/corporate

/mob/living/carbon/human/species/dullahan
	race = /datum/species/dullahan

/mob/living/carbon/human/species/felinid
	race = /datum/species/human/felinid

/mob/living/carbon/human/species/fly
	race = /datum/species/fly

/mob/living/carbon/human/species/golem
	race = /datum/species/golem

/mob/living/carbon/human/species/golem/random
	race = /datum/species/golem/random

/mob/living/carbon/human/species/golem/adamantine
	race = /datum/species/golem/adamantine

/mob/living/carbon/human/species/golem/plasma
	race = /datum/species/golem/plasma

/mob/living/carbon/human/species/golem/diamond
	race = /datum/species/golem/diamond

/mob/living/carbon/human/species/golem/gold
	race = /datum/species/golem/gold

/mob/living/carbon/human/species/golem/silver
	race = /datum/species/golem/silver

/mob/living/carbon/human/species/golem/plasteel
	race = /datum/species/golem/plasteel

/mob/living/carbon/human/species/golem/titanium
	race = /datum/species/golem/titanium

/mob/living/carbon/human/species/golem/plastitanium
	race = /datum/species/golem/plastitanium

/mob/living/carbon/human/species/golem/alien_alloy
	race = /datum/species/golem/alloy

/mob/living/carbon/human/species/golem/wood
	race = /datum/species/golem/wood

/mob/living/carbon/human/species/golem/uranium
	race = /datum/species/golem/uranium

/mob/living/carbon/human/species/golem/sand
	race = /datum/species/golem/sand

/mob/living/carbon/human/species/golem/glass
	race = /datum/species/golem/glass

/mob/living/carbon/human/species/golem/bluespace
	race = /datum/species/golem/bluespace

/mob/living/carbon/human/species/golem/bananium
	race = /datum/species/golem/bananium

/mob/living/carbon/human/species/golem/blood_cult
	race = /datum/species/golem/runic

/mob/living/carbon/human/species/golem/cloth
	race = /datum/species/golem/cloth

/mob/living/carbon/human/species/golem/plastic
	race = /datum/species/golem/plastic

/mob/living/carbon/human/species/golem/bronze
	race = /datum/species/golem/bronze

/mob/living/carbon/human/species/golem/cardboard
	race = /datum/species/golem/cardboard

/mob/living/carbon/human/species/golem/leather
	race = /datum/species/golem/leather

/mob/living/carbon/human/species/golem/bone
	race = /datum/species/golem/bone

/mob/living/carbon/human/species/golem/durathread
	race = /datum/species/golem/durathread

/mob/living/carbon/human/species/golem/snow
	race = /datum/species/golem/snow

/mob/living/carbon/human/species/golem/clockwork
	race = /datum/species/golem/clockwork

/mob/living/carbon/human/species/golem/clockwork/no_scrap
	race = /datum/species/golem/clockwork/no_scrap

/mob/living/carbon/human/species/golem/capitalist
	race = /datum/species/golem/capitalist

/mob/living/carbon/human/species/golem/soviet
	race = /datum/species/golem/soviet

/mob/living/carbon/human/species/golem/cheese
	race = /datum/species/golem/cheese

/mob/living/carbon/human/species/golem/mhydrogen
	race = /datum/species/golem/mhydrogen

/mob/living/carbon/human/species/golem/telecrystal
	race = /datum/species/golem/telecrystal

/mob/living/carbon/human/species/jelly
	race = /datum/species/jelly

/mob/living/carbon/human/species/jelly/slime
	race = /datum/species/jelly/slime

/mob/living/carbon/human/species/jelly/stargazer
	race = /datum/species/jelly/stargazer

/mob/living/carbon/human/species/jelly/luminescent
	race = /datum/species/jelly/luminescent

/mob/living/carbon/human/species/lizard
	race = /datum/species/lizard

/mob/living/carbon/human/species/ethereal
	race = /datum/species/ethereal

/mob/living/carbon/human/species/lizard/ashwalker
	race = /datum/species/lizard/ashwalker

/mob/living/carbon/human/species/moth
	race = /datum/species/moth

/mob/living/carbon/human/species/mush
	race = /datum/species/mush

/mob/living/carbon/human/species/plasma
	race = /datum/species/plasmaman

/mob/living/carbon/human/species/pod
	race = /datum/species/pod

/mob/living/carbon/human/species/polysmorph
	race = /datum/species/polysmorph

/mob/living/carbon/human/species/shadow
	race = /datum/species/shadow

/mob/living/carbon/human/species/shadow/nightmare
	race = /datum/species/shadow/nightmare

/mob/living/carbon/human/species/skeleton
	race = /datum/species/skeleton

/mob/living/carbon/human/species/skeleton/lowcalcium
	race = /datum/species/skeleton/lowcalcium

/mob/living/carbon/human/species/synth
	race = /datum/species/synth

/mob/living/carbon/human/species/synth/military
	race = /datum/species/synth/military

/mob/living/carbon/human/species/vampire
	race = /datum/species/vampire

/mob/living/carbon/human/species/zombie
	race = /datum/species/zombie

/mob/living/carbon/human/species/zombie/infectious
	race = /datum/species/zombie/infectious

/mob/living/carbon/human/species/zombie/krokodil_addict
	race = /datum/species/krokodil_addict

/mob/living/carbon/human/proc/hulk_health_check(oldhealth)
	if(!dna)
		return

	if(dna.check_mutation(ACTIVE_HULK))
		if(health < HEALTH_THRESHOLD_CRIT)
			dna.remove_mutation(ACTIVE_HULK)
			return
		if(health < oldhealth)
			adjustStaminaLoss(-1.5 * (oldhealth - health))
	else
		if(!dna.check_mutation(HULK) && dna.check_mutation(GENETICS_HULK) && stat == CONSCIOUS && (oldhealth >= health + 10 || health < (0.5 * maxHealth)))
			dna.add_mutation(ACTIVE_HULK)

/mob/living/carbon/human/proc/hulk_stamina_check()
	if(dna.check_mutation(ACTIVE_HULK))
		if(staminaloss < 60 && prob(1))
			confused = 7
			say("HULK SMASH!!")
		if(staminaloss >= 90)
			dna.remove_mutation(ACTIVE_HULK)
			to_chat(src, span_notice("You have calm down enough to become human again."))
			Knockdown(6)
		return TRUE
	else
		return FALSE

/mob/living/carbon/human/Bump(atom/movable/AM)
	..()
	if(dna.check_mutation(ACTIVE_HULK) && confused && (world.time - last_bumped) > 15)
		Bumped(AM)
		return AM.attack_hulk(src)
