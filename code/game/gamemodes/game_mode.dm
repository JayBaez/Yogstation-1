/*
 * GAMEMODES (by Rastaf0)
 *
 * In the new mode system all special roles are fully supported.
 * You can have proper wizards/traitors/changelings/cultists during any mode.
 * Only two things really depends on gamemode:
 * 1. Starting roles, equipment and preparations
 * 2. Conditions of finishing the round.
 *
 */


/datum/game_mode
	var/name = "invalid"
	var/config_tag = null
	var/votable = 1
	var/probability = 0
	var/false_report_weight = 0 //How often will this show up incorrectly in a centcom report?
	var/report_type = "invalid" //gamemodes with the same report type will not show up in the command report together.
	var/station_was_nuked = 0 //see nuclearbomb.dm and malfunction.dm
	var/nuke_off_station = 0 //Used for tracking where the nuke hit
	var/round_ends_with_antag_death = 0 //flags the "one verse the station" antags as such
	var/list/datum/mind/antag_candidates = list()	// List of possible starting antags goes here
	var/list/restricted_jobs = list()	// Jobs it doesn't make sense to be.  I.E chaplain or AI cultist
	var/list/protected_jobs = list()	// Jobs that can't be traitors because
	var/list/required_jobs = list()		// alternative required job groups eg list(list(cap=1),list(hos=1,sec=2)) translates to one captain OR one hos and two secmans
	var/lowpop_amount = 30 //The maximum amount of players before lowpop jobs are not restricted
	var/required_players = 0
	var/maximum_players = -1 // -1 is no maximum, positive numbers limit the selection of a mode on overstaffed stations
	var/required_enemies = 0
	var/recommended_enemies = 0
	var/antag_flag = null //preferences flag such as BE_WIZARD that need to be turned on for players to be antag
	var/mob/living/living_antag_player = null
	var/datum/game_mode/replacementmode = null
	var/round_converted = 0 //0: round not converted, 1: round going to convert, 2: round converted
	var/reroll_friendly 	//During mode conversion only these are in the running
	var/continuous_sanity_checked	//Catches some cases where config options could be used to suggest that modes without antagonists should end when all antagonists die
	var/enemy_minimum_age = 7 //How many days must players have been playing before they can play this antagonist

	var/announce_span = "warning" //The gamemode's name will be in this span during announcement.
	var/announce_text = "This gamemode forgot to set a descriptive text! Uh oh!" //Used to describe a gamemode when it's announced.

	// title_icon and title_icon_state are used for the credits that roll at the end
	var/title_icon

	var/const/waittime_l = 600
	var/const/waittime_h = 1800 // started at 1800

	var/list/datum/station_goal/station_goals = list()

	var/allow_persistence_save = TRUE

	var/gamemode_ready = FALSE //Is the gamemode all set up and ready to start checking for ending conditions.
	var/setup_error		//What stopepd setting up the mode.

	/// Associative list of current players, in order: living players, living antagonists, dead players and observers.
	var/list/list/current_players = list(CURRENT_LIVING_PLAYERS = list(), CURRENT_LIVING_ANTAGS = list(), CURRENT_DEAD_PLAYERS = list(), CURRENT_OBSERVERS = list())

/datum/game_mode/proc/announce() //Shows the gamemode's name and a fast description.
	to_chat(world, "<b>The gamemode is: <span class='[announce_span]'>[name]</span>!</b>")
	to_chat(world, "<b>[announce_text]</b>")

/datum/game_mode/proc/admin_panel()
	return


///Checks to see if the game can be setup and ran with the current number of players or whatnot.
/datum/game_mode/proc/can_start()
	var/playerC = 0
	var/unreadiedPlayers = 0
	for(var/mob/dead/new_player/player in GLOB.player_list)
		if(player.client && (player.ready == PLAYER_READY_TO_PLAY))
			playerC++
		else if(player.client && (player.ready == PLAYER_NOT_READY) && !player.client.holder) //Admins don't count :)
			unreadiedPlayers++
	if(!GLOB.Debug2)
		var/adjustedPlayerCount = round(playerC + (unreadiedPlayers * UNREADIED_PLAYER_MULTIPLIER), 1)
		log_game("Round can_start() with [adjustedPlayerCount] adjusted count, versus [playerC] regular player count. Requirement: [required_players] Gamemode: [name]")
		if(adjustedPlayerCount < required_players || (maximum_players >= 0 && playerC > maximum_players))
			return FALSE
	antag_candidates = get_players_for_role(antag_flag)
	if(!GLOB.Debug2)
		if(antag_candidates.len < required_enemies)
			return FALSE
		return TRUE
	else
		message_admins(span_notice("DEBUG: GAME STARTING WITHOUT PLAYER NUMBER CHECKS, THIS WILL PROBABLY BREAK SHIT."))
		return TRUE


///Attempts to select players for special roles the mode might have.
/datum/game_mode/proc/pre_setup()
	return 1

///Everyone should now be on the station and have their normal gear.  This is the place to give the special roles extra things
/datum/game_mode/proc/post_setup(report) //Gamemodes can override the intercept report. Passing TRUE as the argument will force a report.
	SHOULD_CALL_PARENT(TRUE)

	if(!report)
		report = !CONFIG_GET(flag/no_intercept_report)
	addtimer(CALLBACK(GLOBAL_PROC, .proc/display_roundstart_logout_report), ROUNDSTART_LOGOUT_REPORT_TIME)

	if(CONFIG_GET(flag/reopen_roundstart_suicide_roles))
		var/delay = CONFIG_GET(number/reopen_roundstart_suicide_roles_delay)
		if(delay)
			delay = (delay SECONDS)
		else
			delay = (4 MINUTES) //default to 4 minutes if the delay isn't defined.
		addtimer(CALLBACK(GLOBAL_PROC, .proc/reopen_roundstart_suicide_roles), delay)

	if(SSdbcore.Connect())
		var/list/to_set  = list()
		var/arguments  = list()
		if(SSticker.mode)
			to_set += "game_mode = :game_mode"
			arguments ["game_mode"] = SSticker.mode
		if(GLOB.revdata.originmastercommit)
			to_set += "commit_hash = :commit_hash"
			arguments ["commit_hash"] = GLOB.revdata.originmastercommit
		if(to_set.len)
			arguments ["round_id"] = GLOB.round_id
			var/datum/DBQuery/query_round_game_mode = SSdbcore.NewQuery(
				"UPDATE [format_table_name("round")] SET [to_set.Join(", ")] WHERE id = :round_id",
				arguments
			)
			query_round_game_mode.Execute()
			qdel(query_round_game_mode)
	if(report)
		addtimer(CALLBACK(src, .proc/send_intercept, 0), rand(waittime_l, waittime_h))
	generate_station_goals()
	gamemode_ready = TRUE
	return 1


///Handles late-join antag assignments
/datum/game_mode/proc/make_antag_chance(mob/living/carbon/human/character)
	if(replacementmode && round_converted == 2)
		replacementmode.make_antag_chance(character)
	return


///Allows rounds to basically be "rerolled" should the initial premise fall through. Also known as mulligan antags.
/datum/game_mode/proc/convert_roundtype()
	set waitfor = FALSE
	var/list/living_crew = list()

	for(var/mob/Player in GLOB.mob_list)
		if(Player.mind && Player.stat != DEAD && !isnewplayer(Player) && !isbrain(Player) && Player.client)
			living_crew += Player
	var/malc = CONFIG_GET(number/midround_antag_life_check)
	if(living_crew.len / GLOB.joined_player_list.len <= malc) //If a lot of the player base died, we start fresh
		message_admins("Convert_roundtype failed due to too many dead people. Limit is [malc * 100]% living crew")
		return null

	var/list/datum/game_mode/runnable_modes = config.get_runnable_midround_modes(living_crew.len)
	var/list/datum/game_mode/usable_modes = list()
	for(var/datum/game_mode/G in runnable_modes)
		if(G.reroll_friendly && living_crew.len >= G.required_players)
			usable_modes += G
		else
			qdel(G)

	if(!usable_modes.len)
		message_admins("Convert_roundtype failed due to no valid modes to convert to. Please report this error to the Coders.")
		return null

	replacementmode = pickweight(usable_modes)

	switch(SSshuttle.emergency.mode) //Rounds on the verge of ending don't get new antags, they just run out
		if(SHUTTLE_STRANDED, SHUTTLE_ESCAPE)
			return 1
		if(SHUTTLE_CALL)
			if(SSshuttle.emergency.timeLeft(1) < initial(SSshuttle.emergencyCallTime)*0.5)
				return 1

	var/matc = CONFIG_GET(number/midround_antag_time_check)
	if(world.time >= (matc * 600))
		message_admins("Convert_roundtype failed due to round length. Limit is [matc] minutes.")
		return null

	var/list/antag_candidates = list()

	for(var/mob/living/carbon/human/H in living_crew)
		if(H.client && H.client.prefs.allow_midround_antag && !is_centcom_level(H.z))
			antag_candidates += H

	if(!antag_candidates)
		message_admins("Convert_roundtype failed due to no antag candidates.")
		return null

	antag_candidates = shuffle(antag_candidates)

	if(CONFIG_GET(flag/protect_roles_from_antagonist))
		replacementmode.restricted_jobs += replacementmode.protected_jobs
	if(CONFIG_GET(flag/protect_assistant_from_antagonist))
		replacementmode.restricted_jobs += "Assistant"

	message_admins("The roundtype will be converted. If you have other plans for the station or feel the station is too messed up to inhabit <A HREF='?_src_=holder;[HrefToken()];toggle_midround_antag=[REF(usr)]'>stop the creation of antags</A> or <A HREF='?_src_=holder;[HrefToken()];end_round=[REF(usr)]'>end the round now</A>.")
	log_game("Roundtype converted to [replacementmode.name]")

	. = 1

	sleep(rand(600,1800))
	if(!SSticker.IsRoundInProgress())
		message_admins("Roundtype conversion cancelled, the game appears to have finished!")
		round_converted = 0
		return
	 //somewhere between 1 and 3 minutes from now
	if(!CONFIG_GET(keyed_list/midround_antag)[SSticker.mode.config_tag])
		round_converted = 0
		return 1
	for(var/mob/living/carbon/human/H in antag_candidates)
		if(H.client)
			replacementmode.make_antag_chance(H)
	replacementmode.gamemode_ready = TRUE //Awful but we're not doing standard setup here.
	round_converted = 2
	message_admins("-- IMPORTANT: The roundtype has been converted to [replacementmode.name], antagonists may have been created! --")


///Called by the gameSSticker
/datum/game_mode/process()
	return 0

//For things that do not die easily
/datum/game_mode/proc/are_special_antags_dead()
	return TRUE


/datum/game_mode/proc/check_finished(force_ending) //to be called by SSticker
	if(!SSticker.setup_done || !gamemode_ready)
		return FALSE
	if(replacementmode && round_converted == 2)
		return replacementmode.check_finished()
	if(SSshuttle.emergency && (SSshuttle.emergency.mode == SHUTTLE_ENDGAME))
		return TRUE
	if(station_was_nuked)
		return TRUE
	var/list/continuous = CONFIG_GET(keyed_list/continuous)
	var/list/midround_antag = CONFIG_GET(keyed_list/midround_antag)
	if(!round_converted && (!continuous[config_tag] || (continuous[config_tag] && midround_antag[config_tag]))) //Non-continuous or continous with replacement antags
		if(!continuous_sanity_checked) //make sure we have antags to be checking in the first place
			for(var/mob/Player in GLOB.mob_list)
				if(Player.mind)
					if(Player.mind.special_role || LAZYLEN(Player.mind.antag_datums))
						continuous_sanity_checked = 1
						return 0
			if(!continuous_sanity_checked)
				message_admins("The roundtype ([config_tag]) has no antagonists, continuous round has been defaulted to on and midround_antag has been defaulted to off.")
				continuous[config_tag] = TRUE
				midround_antag[config_tag] = FALSE
				SSshuttle.clearHostileEnvironment(src)
				return 0


		if(living_antag_player && living_antag_player.mind && isliving(living_antag_player) && living_antag_player.stat != DEAD && !isnewplayer(living_antag_player) &&!isbrain(living_antag_player) && (living_antag_player.mind.special_role || LAZYLEN(living_antag_player.mind.antag_datums)))
			return 0 //A resource saver: once we find someone who has to die for all antags to be dead, we can just keep checking them, cycling over everyone only when we lose our mark.

		for(var/mob/Player in GLOB.alive_mob_list)
			if(Player.mind && Player.stat != DEAD && !isnewplayer(Player) &&!isbrain(Player) && Player.client && (Player.mind.special_role || LAZYLEN(Player.mind.antag_datums))) //Someone's still antagging but is their antagonist datum important enough to skip mulligan?
				for(var/datum/antagonist/antag_types in Player.mind.antag_datums)
					if(antag_types.prevent_roundtype_conversion)
						living_antag_player = Player //they were an important antag, they're our new mark
						return 0

		if(!are_special_antags_dead())
			return FALSE

		if(!continuous[config_tag] || force_ending)
			return 1

		else
			round_converted = convert_roundtype()
			if(!round_converted)
				if(round_ends_with_antag_death)
					return 1
				else
					midround_antag[config_tag] = 0
					return 0

	return 0


/datum/game_mode/proc/check_win() //universal trigger to be called at mob death, nuke explosion, etc. To be called from everywhere.
	return 0

/datum/game_mode/proc/send_intercept()
	var/intercepttext = "<b><i>Central Command Status Summary</i></b><hr>"
	intercepttext += "<b>Central Command has intercepted and partially decoded a Syndicate transmission with vital information regarding their movements. The following report outlines the most \
	likely threats to appear in your sector.</b>"
	var/list/report_weights = config.mode_false_report_weight.Copy()
	report_weights[report_type] = 0 //Prevent the current mode from being falsely selected.
	var/list/reports = list()
	var/Count = 0 //To compensate for missing correct report
	if(prob(65)) // 65% chance the actual mode will appear on the list
		reports += config.mode_reports[report_type]
		Count++
	for(var/i in Count to rand(3,5)) //Between three and five wrong entries on the list.
		var/false_report_type = pickweightAllowZero(report_weights)
		report_weights[false_report_type] = 0 //Make it so the same false report won't be selected twice
		reports += config.mode_reports[false_report_type]

	reports = shuffle(reports) //Randomize the order, so the real one is at a random position.

	for(var/report in reports)
		intercepttext += "<hr>"
		intercepttext += report

	intercepttext += generate_station_goal_report()
	intercepttext += generate_station_trait_report()

	print_command_report(intercepttext, "Central Command Status Summary", announce=FALSE)
	priority_announce("A summary has been copied and printed to all communications consoles.\n\n[generate_station_trait_announcement()]", "Enemy communication intercepted. Security level elevated.", ANNOUNCER_INTERCEPT)
	if(GLOB.security_level < SEC_LEVEL_BLUE)
		set_security_level(SEC_LEVEL_BLUE)
		
/*
 * Generate a list of station goals available to purchase to report to the crew.
 *
 * Returns a formatted string all station goals that are available to the station.
 */
/datum/game_mode/proc/generate_station_goal_report()
	if(!station_goals.len)
		return
	. = "<hr><b>Special Orders for [station_name()]:</b><BR>"
	for(var/datum/station_goal/station_goal in station_goals)
		station_goal.on_report()
		. += station_goal.get_report()
	return
	
/*
 * Generate a list of active station traits to report to the crew.
 *
 * Returns a formatted string of all station traits (that are shown) affecting the station.
 */
/datum/game_mode/proc/generate_station_trait_report()
	if(!SSstation.station_traits.len)
		return
	. = "<hr><b>Identified shift divergencies:</b><BR>"
	for(var/datum/station_trait/station_trait as anything in SSstation.station_traits)
		if(!station_trait.show_in_report)
			continue
		. += "[station_trait.get_report()]<BR>"
	return
	
/datum/game_mode/proc/generate_station_trait_announcement()
	if(!SSstation.station_traits.len)
		return
	. = "Identified shift divergencies:\n"
	for(var/datum/station_trait/station_trait as anything in SSstation.station_traits)
		if(!station_trait.show_in_report)
			continue
		. += "[station_trait.get_report()]\n"
	return

// This is a frequency selection system. You may imagine it like a raffle where each player can have some number of tickets. The more tickets you have the more likely you are to
// "win". The default is 100 tickets. If no players use any extra tickets (earned with the antagonist rep system) calling this function should be equivalent to calling the normal
// pick() function. By default you may use up to 100 extra tickets per roll, meaning at maximum a player may double their chances compared to a player who has no extra tickets.
//
// The odds of being picked are simply (your_tickets / total_tickets). Suppose you have one player using fifty (50) extra tickets, and one who uses no extra:
//     Player A: 150 tickets
//     Player B: 100 tickets
//        Total: 250 tickets
//
// The odds become:
//     Player A: 150 / 250 = 0.6 = 60%
//     Player B: 100 / 250 = 0.4 = 40%
/datum/game_mode/proc/antag_pick(list/datum/candidates)
	if(GLOB.antag_token_users.len >= 1) //Antag token users get first priority, no matter their preferences
		var/client/C = pick_n_take(GLOB.antag_token_users)
		var/mob/M = C.mob
		if(C && istype(M, /mob/dead/new_player))
			var/mob/dead/new_player/player = M
			if(player.ready == PLAYER_READY_TO_PLAY)
				if(!is_banned_from(player.ckey, list(antag_flag, ROLE_SYNDICATE)) && !QDELETED(player))
					addtimer(CALLBACK(GLOBAL_PROC, .proc/antag_token_used, C.ckey, C), 5 MINUTES + 10 SECONDS)
					player.mind.token_picked = TRUE
					return player.mind

	if(!CONFIG_GET(flag/use_antag_rep)) // || candidates.len <= 1)
		return pick(candidates)

	// Tickets start at 100
	var/DEFAULT_ANTAG_TICKETS = CONFIG_GET(number/default_antag_tickets)

	// You may use up to 100 extra tickets (double your odds)
	var/MAX_TICKETS_PER_ROLL = CONFIG_GET(number/max_tickets_per_roll)


	var/total_tickets = 0

	MAX_TICKETS_PER_ROLL += DEFAULT_ANTAG_TICKETS

	var/p_ckey
	var/p_rep

	for(var/datum/mind/mind in candidates)
		p_ckey = ckey(mind.key)
		total_tickets += min(SSpersistence.antag_rep[p_ckey] + DEFAULT_ANTAG_TICKETS, MAX_TICKETS_PER_ROLL)

	var/antag_select = rand(1,total_tickets)
	var/current = 1

	for(var/datum/mind/mind in candidates)
		p_ckey = ckey(mind.key)
		p_rep = SSpersistence.antag_rep[p_ckey]

		var/previous = current
		var/spend = min(p_rep + DEFAULT_ANTAG_TICKETS, MAX_TICKETS_PER_ROLL)
		current += spend

		if(antag_select >= previous && antag_select <= (current-1))
			SSpersistence.antag_rep_change[p_ckey] = -(spend - DEFAULT_ANTAG_TICKETS)

//			WARNING("AR_DEBUG: Player [mind.key] won spending [spend] tickets from starting value [SSpersistence.antag_rep[p_ckey]]")

			//yogs start -- quiet mode
			if(mind.quiet_round)
				to_chat(mind.current,span_userdanger("There aren't enough antag volunteers, so your quiet round setting will not be considered!"))
			//yogs end
			return mind

	WARNING("Something has gone terribly wrong. /datum/game_mode/proc/antag_pick failed to select a candidate. Falling back to pick()")
	return pick(candidates)

/datum/game_mode/proc/get_players_for_role(role) //YOGS -- MIRRORED IN THE YOGSTATION FOLDER! DO NOT EAT, SWALLOW, OR SUBMURGE IN ACID
	var/list/players = list()
	var/list/candidates = list()
	var/list/drafted = list()
	var/datum/mind/applicant = null

	// Ultimate randomizing code right here
	for(var/mob/dead/new_player/player in GLOB.player_list)
		if(player.client && player.ready == PLAYER_READY_TO_PLAY && player.check_preferences())
			players += player

	// Shuffling, the players list is now ping-independent!!!
	// Goodbye antag dante
	players = shuffle(players)

	for(var/mob/dead/new_player/player in players)
		if(player.client && player.ready == PLAYER_READY_TO_PLAY)
			if(role in player.client.prefs.be_special)
				if(!is_banned_from(player.ckey, list(role, ROLE_SYNDICATE)) && !QDELETED(player))
					if(age_check(player.client)) //Must be older than the minimum age
						candidates += player.mind				// Get a list of all the people who want to be the antagonist for this round

	if(restricted_jobs)
		for(var/datum/mind/player in candidates)
			for(var/job in restricted_jobs)					// Remove people who want to be antagonist but have a job already that precludes it
				if(player.assigned_role == job)
					candidates -= player

	if(candidates.len < recommended_enemies)
		for(var/mob/dead/new_player/player in players)
			if(player.client && player.ready == PLAYER_READY_TO_PLAY)
				if(!(role in player.client.prefs.be_special)) // We don't have enough people who want to be antagonist, make a separate list of people who don't want to be one
					if(!is_banned_from(player.ckey, list(role, ROLE_SYNDICATE)) && !QDELETED(player))
						drafted += player.mind

	if(restricted_jobs)
		for(var/datum/mind/player in drafted)				// Remove people who can't be an antagonist
			for(var/job in restricted_jobs)
				if(player.assigned_role == job)
					drafted -= player

	drafted = shuffle(drafted) // Will hopefully increase randomness, Donkie

	while(candidates.len < recommended_enemies)				// Pick randomlly just the number of people we need and add them to our list of candidates
		if(drafted.len > 0)
			applicant = pick(drafted)
			if(applicant)
				candidates += applicant
				drafted.Remove(applicant)

		else												// Not enough scrubs, ABORT ABORT ABORT
			break

	return candidates		// Returns: The number of people who had the antagonist role set to yes, regardless of recomended_enemies, if that number is greater than recommended_enemies
							//			recommended_enemies if the number of people with that role set to yes is less than recomended_enemies,
							//			Less if there are not enough valid players in the game entirely to make recommended_enemies.



/datum/game_mode/proc/num_players()
	. = 0
	for(var/mob/dead/new_player/P in GLOB.player_list)
		if(P.client && P.ready == PLAYER_READY_TO_PLAY)
			. ++

/proc/reopen_roundstart_suicide_roles()
	var/list/valid_positions = list()
	valid_positions += GLOB.engineering_positions
	valid_positions += GLOB.medical_positions
	valid_positions += GLOB.science_positions
	valid_positions += GLOB.supply_positions
	valid_positions += GLOB.civilian_positions
	valid_positions += GLOB.security_positions
	if(CONFIG_GET(flag/reopen_roundstart_suicide_roles_command_positions))
		valid_positions += GLOB.command_positions //add any remaining command positions
	else
		valid_positions -= GLOB.command_positions //remove all command positions that were added from their respective department positions lists.

	var/list/reopened_jobs = list()
	for(var/X in GLOB.suicided_mob_list)
		if(!isliving(X))
			continue
		var/mob/living/L = X
		if(L.job in valid_positions)
			var/datum/job/J = SSjob.GetJob(L.job)
			if(!J)
				continue
			J.current_positions = max(J.current_positions-1, 0)
			reopened_jobs += L.job

	if(CONFIG_GET(flag/reopen_roundstart_suicide_roles_command_report))
		if(reopened_jobs.len)
			var/reopened_job_report_positions
			for(var/dead_dudes_job in reopened_jobs)
				reopened_job_report_positions = "[reopened_job_report_positions ? "[reopened_job_report_positions]\n":""][dead_dudes_job]"

			var/suicide_command_report = "<font size = 3><b>Central Command Human Resources Board</b><br>\
								Notice of Personnel Change</font><hr>\
								To personnel management staff aboard [station_name()]:<br><br>\
								Our medical staff have detected a series of anomalies in the vital sensors \
								of some of the staff aboard your station.<br><br>\
								Further investigation into the situation on our end resulted in us discovering \
								a series of rather... unforturnate decisions that were made on the part of said staff.<br><br>\
								As such, we have taken the liberty to automatically reopen employment opportunities for the positions of the crew members \
								who have decided not to partake in our research. We will be forwarding their cases to our employment review board \
								to determine their eligibility for continued service with the company (and of course the \
								continued storage of cloning records within the central medical backup server.)<br><br>\
								<i>The following positions have been reopened on our behalf:<br><br>\
								[reopened_job_report_positions]</i>"

			print_command_report(suicide_command_report, "Central Command Personnel Update")

/datum/game_mode/proc/get_living_by_department(var/department)
	. = list()
	for(var/mob/living/carbon/human/player in GLOB.mob_list)
		if(player.stat != DEAD && player.mind && (player.mind.assigned_role in department))
			. |= player.mind

/datum/game_mode/proc/get_all_by_department(var/department)
	. = list()
	for(var/mob/player in GLOB.mob_list)
		if(player.mind && (player.mind.assigned_role in department))
			. |= player.mind

/////////////////////////////////////////////
//Keeps track of all living silicon members//
/////////////////////////////////////////////
/datum/game_mode/proc/get_living_silicon()
	. = list()
	for(var/mob/living/silicon/player in GLOB.mob_list)
		if(player.stat != DEAD && player.mind && (player.mind.assigned_role in GLOB.nonhuman_positions))
			. |= player.mind

///////////////////////////////////////
//Keeps track of all silicon members //
///////////////////////////////////////
/datum/game_mode/proc/get_all_silicon()
	. = list()
	for(var/mob/living/silicon/player in GLOB.mob_list)
		if(player.mind && (player.mind.assigned_role in GLOB.nonhuman_positions))
			. |= player.mind

//////////////////////////
//Reports player logouts//
//////////////////////////
/proc/display_roundstart_logout_report()
	var/list/msg = list(span_boldnotice("Roundstart logout report\n\n"))
	for(var/i in GLOB.mob_living_list)
		var/mob/living/L = i
		var/mob/living/carbon/C = L
		if (istype(C) && !C.last_mind)
			continue  // never had a client

		if(L.ckey && !GLOB.directory[L.ckey])
			msg += "<b>[L.name]</b> ([L.key]), the [L.job] (<font color='#ffcc00'><b>Disconnected</b></font>)\n"


		if(L.ckey && L.client)
			var/failed = FALSE
			if(L.client.inactivity >= (ROUNDSTART_LOGOUT_REPORT_TIME / 2))	//Connected, but inactive (alt+tabbed or something)
				msg += "<b>[L.name]</b> ([L.key]), the [L.job] (<font color='#ffcc00'><b>Connected, Inactive</b></font>)\n"
				failed = TRUE //AFK client
			if(!failed && L.stat)
				if(L.suiciding)	//Suicider
					msg += "<b>[L.name]</b> ([L.key]), the [L.job] ([span_boldannounce("Suicide")])\n"
					failed = TRUE //Disconnected client
				if(!failed && L.stat == UNCONSCIOUS)
					msg += "<b>[L.name]</b> ([L.key]), the [L.job] (Dying)\n"
					failed = TRUE //Unconscious
				if(!failed && L.stat == DEAD)
					msg += "<b>[L.name]</b> ([L.key]), the [L.job] (Dead)\n"
					failed = TRUE //Dead

			var/p_ckey = L.client.ckey
//			WARNING("AR_DEBUG: [p_ckey]: failed - [failed], antag_rep_change: [SSpersistence.antag_rep_change[p_ckey]]")

			// people who died or left should not gain any reputation
			// people who rolled antagonist still lose it
			if(failed && SSpersistence.antag_rep_change[p_ckey] > 0)
//				WARNING("AR_DEBUG: Zeroed [p_ckey]'s antag_rep_change")
				SSpersistence.antag_rep_change[p_ckey] = 0

			continue //Happy connected client
		for(var/mob/dead/observer/D in GLOB.dead_mob_list)
			if(D.mind && D.mind.current == L)
				if(L.stat == DEAD)
					if(L.suiciding)	//Suicider
						msg += "<b>[L.name]</b> ([ckey(D.mind.key)]), the [L.job] ([span_boldannounce("Suicide")])\n"
						continue //Disconnected client
					else
						msg += "<b>[L.name]</b> ([ckey(D.mind.key)]), the [L.job] (Dead)\n"
						continue //Dead mob, ghost abandoned
				else
					if(D.can_reenter_corpse)
						continue //Adminghost, or cult/wizard ghost
					else
						msg += "<b>[L.name]</b> ([ckey(D.mind.key)]), the [L.job] ([span_boldannounce("Ghosted")])\n"
						continue //Ghosted while alive


	for (var/C in GLOB.admins)
		to_chat(C, msg.Join())
		log_admin(msg.Join())
//If the configuration option is set to require players to be logged as old enough to play certain jobs, then this proc checks that they are, otherwise it just returns 1
/datum/game_mode/proc/age_check(client/C)
	if(get_remaining_days(C) == 0)
		return 1	//Available in 0 days = available right now = player is old enough to play.
	return 0


/datum/game_mode/proc/get_remaining_days(client/C)
	if(!C)
		return 0
	if(!CONFIG_GET(flag/use_age_restriction_for_jobs))
		return 0
	if(C.player_age < 0)
		return 0
	if(!isnum(enemy_minimum_age))
		return 0

	return max(0, enemy_minimum_age - C.player_age)

/datum/game_mode/proc/remove_antag_for_borging(datum/mind/newborgie)
	SSticker.mode.remove_cultist(newborgie, 0, 0)
	var/datum/antagonist/rev/rev = newborgie.has_antag_datum(/datum/antagonist/rev)
	if(rev)
		rev.remove_revolutionary(TRUE)

/datum/game_mode/proc/generate_station_goals()
	for(var/T in subtypesof(/datum/station_goal))
		var/datum/station_goal/G = T
		if(config_tag in initial(G.gamemode_blacklist))
			continue
		station_goals += new T

/datum/game_mode/proc/generate_report() //Generates a small text blurb for the gamemode in centcom report
	return "Gamemode report for [name] not set.  Contact a coder."

//By default nuke just ends the round
/datum/game_mode/proc/OnNukeExplosion(off_station)
	nuke_off_station = off_station
	if(off_station < 2)
		station_was_nuked = TRUE //Will end the round on next check.

//Additional report section in roundend report
/datum/game_mode/proc/special_report()
	return

//Set result and news report here
/datum/game_mode/proc/set_round_result()
	SSticker.mode_result = "undefined"
	if(station_was_nuked)
		SSticker.news_report = STATION_DESTROYED_NUKE
	if(EMERGENCY_ESCAPED_OR_ENDGAMED)
		SSticker.news_report = STATION_EVACUATED
		if(SSshuttle.emergency.is_hijacked())
			SSticker.news_report = SHUTTLE_HIJACK

/**
  * Given a list of minds, returns TRUE if they completed all their objectives, FALSE otherwise
  *
  * Arguments:
  * * antags - list of minds that we're checking
  * * antagonist_datum - The type we're checking for, is optional
  */
/datum/game_mode/proc/didAntagsWin(list/antags, datum/antagonist/antagonist_datum)
	for(var/m in antags)
		var/datum/mind/mind = m
		for(var/a in mind.antag_datums)
			var/datum/antagonist/antagonist = a
			if(antagonist_datum && !istype(antagonist, antagonist_datum))
				continue
			for(var/o in antagonist.objectives)
				var/datum/objective/objective = o
				if(!objective.check_completion())
					return FALSE
	return TRUE

/datum/game_mode/proc/AdminPanelEntry()
	return

/datum/game_mode/proc/generate_credit_text()
	var/list/round_credits = list()
	var/len_before_addition

	// HEADS OF STAFF
	round_credits += "<center><h1>The Glorious Command Staff:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.command_positions))
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>A serious bureaucratic error has occurred!</h2>", "<center><h2>No one was in charge of the crew!</h2>")
	round_credits += "<br>"

	// SILICONS
	round_credits += "<center><h1>The Silicon \"Intelligences\":</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_silicon())
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>[station_name()] had no silicon helpers!</h2>", "<center><h2>Not a single door was opened today!</h2>")
	round_credits += "<br>"

	// SECURITY
	round_credits += "<center><h1>The Brave Security Officers:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.security_positions))
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>[station_name()] has fallen to Communism!</h2>", "<center><h2>No one was there to protect the crew!</h2>")
	round_credits += "<br>"

	// MEDICAL
	round_credits += "<center><h1>The Wise Medical Department:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.medical_positions))
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>Healthcare was not included!</h2>", "<center><h2>There were no doctors today!</h2>")
	round_credits += "<br>"

	// ENGINEERING
	round_credits += "<center><h1>The Industrious Engineers:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.engineering_positions))
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>[station_name()] probably did not last long!</h2>", "<center><h2>No one was holding the station together!</h2>")
	round_credits += "<br>"

	// SCIENCE
	round_credits += "<center><h1>The Inventive Science Employees:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.science_positions))
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>No one was doing \"science\" today!</h2>", "<center><h2>Everyone probably made it out alright, then!</h2>")
	round_credits += "<br>"

	// CARGO
	round_credits += "<center><h1>The Rugged Cargo Crew:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.supply_positions))
		round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>The station was freed from paperwork!</h2>", "<center><h2>No one worked in cargo today!</h2>")
	round_credits += "<br>"

	// CIVILIANS
	var/list/human_garbage = list()
	round_credits += "<center><h1>The Hardy Civilians:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in SSticker.mode.get_all_by_department(GLOB.civilian_positions))
		if(current.assigned_role == "Assistant")
			human_garbage += current
		else
			round_credits += "<center><h2>[current.name] as the [current.assigned_role]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>Everyone was stuck in traffic this morning!</h2>", "<center><h2>No civilians made it to work!</h2>")
	round_credits += "<br>"

	round_credits += "<center><h1>The Helpful Assistants:</h1>"
	len_before_addition = round_credits.len
	for(var/datum/mind/current in human_garbage)
		round_credits += "<center><h2>[current.name]</h2>"
	if(round_credits.len == len_before_addition)
		round_credits += list("<center><h2>The station was free of <s>greytide</s> assistance!</h2>", "<center><h2>Not a single Assistant showed up on the station today!</h2>")

	round_credits += "<br>"
	round_credits += "<br>"

	return round_credits
