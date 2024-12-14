local m = {}

m.categories =
{
	["Auto:Fuel"] = "Auto:Fuel",
	["Entertainment:Food"] = "Entertainment:Food",
	["Groceries"] = "Groceries",
	["Household"] = "Household",
	["Home Repair"] = "Home Repair",
	["Software"] = "Software",
	["Taxes:Sales"] = "Taxes:Sales",
}


m.item_to_category =
{
	["gas"] = m.categories["Auto:Fuel"],

	["glove"] = m.categories["Clothing"],
	["pants"] = m.categories["Clothing"],
	["shirt"] = m.categories["Clothing"],
	["sock"] = m.categories["Clothing"],
	["wear"] = m.categories["Clothing"],



	["chicken"] = m.categories["Groceries"],
	["beef"] = m.categories["Groceries"],
	["pork"] = m.categories["Groceries"],
	["salmon"] = m.categories["Groceries"],
	["turkey"] = m.categories["Groceries"],
	["meat"] = m.categories["Groceries"],
	["peanut"] = m.categories["Groceries"],
	["butter"] = m.categories["Groceries"],
	["spread"] = m.categories["Groceries"],
	["bread"] = m.categories["Groceries"],
	["wheat"] = m.categories["Groceries"],
	["yeast"] = m.categories["Groceries"],
	["oat"] = m.categories["Groceries"],
	["quaker"] = m.categories["Groceries"],
	["baguette"] = m.categories["Groceries"],
	["broc"] = m.categories["Groceries"],
	["choy"] = m.categories["Groceries"],
	["spinach"] = m.categories["Groceries"],
	["squash"] = m.categories["Groceries"],
	["carrot"] = m.categories["Groceries"],
	["celery"] = m.categories["Groceries"],
	["potato"] = m.categories["Groceries"],
	["onion"] = m.categories["Groceries"],
	["mushroom"] = m.categories["Groceries"],
	["portofino"] = m.categories["Groceries"],
	["tomato"] = m.categories["Groceries"],
	["apple"] = m.categories["Groceries"],
	["banana"] = m.categories["Groceries"],
	["lemon"] = m.categories["Groceries"],
	["grape"] = m.categories["Groceries"],
	["artichoke"] = m.categories["Groceries"],
	["garlic"] = m.categories["Groceries"],
	["veg"] = m.categories["Groceries"],
	["organic"] = m.categories["Groceries"],
	["vinegar"] = m.categories["Groceries"],
	["vngr"] = m.categories["Groceries"],
	["pepper"] = m.categories["Groceries"],
	["salt"] = m.categories["Groceries"],
	["choc"] = m.categories["Groceries"],
	["cheese"] = m.categories["Groceries"],
	["cream"] = m.categories["Groceries"],
	["yogurt"] = m.categories["Groceries"],
	["ygt"] = m.categories["Groceries"],
	["milk"] = m.categories["Groceries"],
	["lactose"] = m.categories["Groceries"],
	["egg"] = m.categories["Groceries"],
	["tuna"] = m.categories["Groceries"],
	["corn"] = m.categories["Groceries"],
	["EVOO"] = m.categories["Groceries"], -- Extra Virgin Olive Oil
	["olive"] = m.categories["Groceries"],
	["oil"] = m.categories["Groceries"],
	["chili"] = m.categories["Groceries"],
	["chip"] = m.categories["Groceries"],
	["dip"] = m.categories["Groceries"],
	["syrup"] = m.categories["Groceries"],
	["rice"] = m.categories["Groceries"],
	["flour"] = m.categories["Groceries"],
	["noodle"] = m.categories["Groceries"],
	["quinoa"] = m.categories["Groceries"],
	["tofu"] = m.categories["Groceries"],
	["pepsi"] = m.categories["Groceries"],
	["cola"] = m.categories["Groceries"],
	["coke"] = m.categories["Groceries"],
	["water"] = m.categories["Groceries"],
	["cajun"] = m.categories["Groceries"],
	["tumeric"] = m.categories["Groceries"],
	["nut"] = m.categories["Groceries"],
	["almond"] = m.categories["Groceries"],
	["cake"] = m.categories["Groceries"],
	["vanilla"] = m.categories["Groceries"],
	["cheerios"] = m.categories["Groceries"],
	["bcn"] = m.categories["Groceries"],
	["reddi wip"] = m.categories["Groceries"],
	["keychup"] = m.categories["Groceries"],
	["mayo"] = m.categories["Groceries"],
	["shrd"] = m.categories["Groceries"],
	["honey"] = m.categories["Groceries"],
	["hny"] = m.categories["Groceries"],
	["gatorade"] = m.categories["Groceries"],
	["curry"] = m.categories["Groceries"],
	["country crck"] = m.categories["Groceries"],
	["peas"] = m.categories["Groceries"],
	["rasin"] = m.categories["Groceries"],
	["sriracha"] = m.categories["Groceries"],
	["sauce"] = m.categories["Groceries"],
	["tom paste"] = m.categories["Groceries"],
	["fuji"] = m.categories["Groceries"],
	["berry"] = m.categories["Groceries"],
	["strwbrry"] = m.categories["Groceries"],
	["skippy"] = m.categories["Groceries"],
	["whey"] = m.categories["Groceries"],
	["pprmnt"] = m.categories["Groceries"],
	["peppmnt"] = m.categories["Groceries"],
	["ghir"] = m.categories["Groceries"],
	["popcorn"] = m.categories["Groceries"],
	["doritos"] = m.categories["Groceries"],

	-- ground beef tubes
	["tubes"] = m.categories["Groceries"],

	-- Should this be with the food court group?
	["rotisserie"] = m.categories["Groceries"],


	["bleach"] = m.categories["Household"],
	["blch"] = m.categories["Household"],
	["toilet"] = m.categories["Household"],
	["lysol"] = m.categories["Household"],
	["comet"] = m.categories["Household"],
	["clean"] = m.categories["Household"],
	["towel"] = m.categories["Household"],
	["dawn"] = m.categories["Household"],
	["9V"] = m.categories["Household"],
	["AA"] = m.categories["Household"],
	["AAA"] = m.categories["Household"],
	["batt"] = m.categories["Household"],



	-- Food court: These might conflict with other keywords in groceries.
	["hot dog/soda"] = m.categories["Entertainment:Food"],
	["pizz"] = m.categories["Entertainment:Food"],
	["chicken bake"] = m.categories["Entertainment:Food"],
	["smooth"] = m.categories["Entertainment:Food"],


	["nyquil"] = m.categories["Medicine"],


	["g2 black ast"] = m.categories["Office"],
	["file folder"] = m.categories["Office"],
	["envl"] = m.categories["Office"],


	["rebate"] = m.categories["Rebate"],


	["turbotax"] = m.categories["Software"],
	["tt home/busi"] = m.categories["Software"],
	["tt business"] = m.categories["Software"],
	["tt home"] = m.categories["Software"],


	["floss"] = m.categories["Toiletries"],
	["mouthwash"] = m.categories["Toiletries"],
	["soap"] = m.categories["Toiletries"],
	["shamp"] = m.categories["Toiletries"],
	["pantene"] = m.categories["Toiletries"],
	["toothpaste"] = m.categories["Toiletries"],

}



return m
