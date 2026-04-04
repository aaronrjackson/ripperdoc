extends Node

var current_customer: Customer = null
var installed_drivers: Array[String] = []

signal customer_loaded(customer: Customer)
signal driver_installed(driver_name: String)
signal customer_dismissed

func _ready() -> void:
	randomize()
	#TODO: TEMP TEST REMOVE ME LATER!!!
	call_deferred("load_customer", load("res://customer/customers/test_customer.tres"))

func load_customer(customer: Customer) -> void:
	current_customer = customer
	installed_drivers.clear()
	customer_loaded.emit(customer)
	print("loaded new customer: " + customer.customer_name)

func install_driver(driver_name: String) -> bool:
	if driver_name in installed_drivers:
		print("DRIVER ALREADY INSTALLED!")
		return false
	installed_drivers.append(driver_name)
	driver_installed.emit(driver_name)
	return true

func all_drivers_installed() -> bool:
	if current_customer == null:
		return false
	for cyberware in current_customer.cyberware:
		for driver in cyberware.drivers:
			if driver.driver_name not in installed_drivers:
				return false
	return true

func dismiss_customer() -> void:
	current_customer = null
	installed_drivers.clear()
	customer_dismissed.emit()
