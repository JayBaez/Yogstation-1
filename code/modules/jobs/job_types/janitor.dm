/datum/job/janitor
	title = "Janitor"
	flag = JANITOR
	department_head = list("Head of Personnel")
	department_flag = CIVILIAN
	faction = "Station"
	total_positions = 2
	spawn_positions = 1
	supervisors = "the head of personnel"
	selection_color = "#bbe291"

	outfit = /datum/outfit/job/janitor

	alt_titles = list("Custodian", "Sanitation Worker", "Cleaner", "Caretaker", "Maid")

	access = list(ACCESS_JANITOR, ACCESS_MAINT_TUNNELS, ACCESS_MINERAL_STOREROOM)
	minimal_access = list(ACCESS_JANITOR, ACCESS_MAINT_TUNNELS, ACCESS_MINERAL_STOREROOM)
	paycheck = PAYCHECK_EASY
	paycheck_department = ACCOUNT_SRV

	display_order = JOB_DISPLAY_ORDER_JANITOR

	changed_maps = list("OmegaStation", "EclipseStation")

/datum/job/janitor/proc/OmegaStationChanges()
	access = list(ACCESS_JANITOR, ACCESS_HYDROPONICS, ACCESS_BAR, ACCESS_KITCHEN, ACCESS_MORGUE, ACCESS_MAINT_TUNNELS)
	minimal_access = list(ACCESS_JANITOR, ACCESS_HYDROPONICS, ACCESS_BAR, ACCESS_KITCHEN, ACCESS_MORGUE, ACCESS_MAINT_TUNNELS)
	supervisors = "the captain and the head of personnel"

/datum/job/janitor/proc/EclipseStationChanges()
	total_positions = 4
	spawn_positions = 2

/datum/outfit/job/janitor
	name = "Janitor"
	jobtype = /datum/job/janitor

	belt = /obj/item/pda/janitor
	ears = /obj/item/radio/headset/headset_srv
	uniform = /obj/item/clothing/under/rank/janitor
