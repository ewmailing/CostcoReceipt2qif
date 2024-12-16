# CostcoReceipt2qif

This converts Costco receipt data into a .qif file which you can import into your personal finance software.
Each receipt is generated into a split-transaction, with categories pre-populated, and coupons marked with tags.

There are two programs in this repository.

- json2qif.lua: Converts Costco receipt .json files downloaded using the tool found at https://github.com/ankurdave/beancount_import_sources/blob/main/download/download_costco_receipts.js
- csv2qif.lua: Converts Costco receipt .csv files downloaded using the tool from https://github.com/drewvolz/costco-receipt-parser

json2qif is the fuller-featured tool you should use. It uses the richer data set to do things like try to match Payee fields to match what Citi Costo Visa writes in its credit card transactions, and also break up multiple quanities so you can more easily see the price per unit, which makes it easier to track price changes over time due to inflation or other events. It also handles return receipts (where you returned items and get a new receipt for the return with a corresponding credit card refund). Because the beancount tool batch pulls multiple receipts, each receipt will become a separate split transaction inside the single outputed .qif file.

csv2qif only has 3 fields to work with. It was written in a few hours, and then I immediately wrote json2qif. This works well enough that I decided to save it in this repo instead of deleting it. It will most likely not handle return receipts.

![Alt text](docs/Costco2qif_SEEFinance.png?raw=true "Example: Imported costco.qif in SEE Finance")


# Usage

- Install Lua if you don't already have it. Tested with Lua 5.4, but I think anything from 5.2 and later should work. (I have one instance of a goto used as a continue statement, which I didn't feel like changing for 5.0 & 5.1 support.)

```bash
lua json2qif.lua ~/Downloads/costco-2024-12-13T06_09_56.747Z.json 
```

```bash
lua csv2qif.lua ~/Downloads/costco-11-26-2024.csv 
```

Both tools support an optional second parameter specifying the output file path and name.

```bash
lua json2qif.lua ~/Downloads/costco-2024-12-13T06_09_56.747Z.json ~/Downloads/costco-2024-12-13.qif
```

json2qif also supports the --recent (-r is the short alias) parameter that will limit the number of receipts processed to the most recent number that you specify. 

```bash
# Only process the most recent receipt
lua json2qif.lua --recent 1 ~/Downloads/costco-2024-12-13T06_09_56.747Z.json

# Only process the 3 most recent receipts
lua json2qif.lua -r3 ~/Downloads/costco-2024-12-13T06_09_56.747Z.json

```

# How to customize catorgories for your own use
There is a separate Lua file (module) called categories.lua so it would be easier for people to modify.

If you want to change the category names written to the QIF,
change the right-side string name to what you want in the m.categories table.

For example, if you want to change the category name "Groceries" to "Food", look for the Groceries key/value pair in m.categories:
```lua
m.categories =
{
	["Auto:Fuel"] = "Auto:Fuel",
	["Clothing"] = "Clothing",
	["Groceries"] = "Groceries",
}
```
and change the value (right-side of the assignment) to Food.
```lua
m.categories =
{
	["Auto:Fuel"] = "Auto:Fuel",
	["Clothing"] = "Clothing",
	["Groceries"] = "Food",
}
```

Alternatively, you could also globally replace all the instances of "Groceries" with "Food" in the entire file. But be aware, "Taxes:Sales" is directly referred to by the main code, so that is special and cannot be changed without also changing the main code.

To add new item/category mappings, add new key/value pairs to m.item_to_category. As an example, this is how you would add eggplant to the Groceries category:
```lua
m.item_to_category =
{
	["gas"] = m.categories["Auto:Fuel"],
	["pants"] = m.categories["Clothing"],
	["chicken"] = m.categories["Groceries"],
	["eggplant"] = m.categories["Groceries"],
}
```

Be aware that this is a simple keyword matching. For every item description, each keyword provided in this table is string compared (case-insensitive) to see if the description contains that substring. If it matches, the associated category is assigned. If no match is found, the category will be left blank. If there are multiple keywords that can match the same description, it assigns whatever happens to match first. Since these are hash lookups, the order is non-determinstic. Delete item/category pairs if this is a problem for you.


# Additional Notes:
json2qif separates multiple quantity purchases into multiple entries. The reason is that I was interested in seeing how prices for items change over time, for reasons such as inflation. QIF does not support quantity, nor price per unit. So the only solution was to break up the multiple-unit entry into multiple entries.
And since the json data also separates coupons into their own entries, I preserve that.

I also added a tag called coupon to denote it is a coupon, so reports/searches can be done on coupons.
I didn't want to change the category because I felt it should be matched to the original item,
otherwise when you do big yearly reports, the report will overstate what you actually spent on e.g. Groceries,
and it will not be easy to see which coupons go with which categories. TAGS add a second dimension.


# Financial Software
.QIF is the Quicken Interchange Format. I use SEE Finance and all my testing was done for that. I presume other software that support .qif, such as Quicken, MoneyDance, GnuCash, etc., will all work, but it is untested.


