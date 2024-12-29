#!/usr/bin/env lua

--[[
Copyright (c) Eric Wing

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
--]]

--[==[

Converts the CSV output from 
https://github.com/drewvolz/costco-receipt-parser

CSV looks like:
id,title,price
"37220","CHOC CHUNK",9.99
"692731","KS ORG EVOO",24.99
"97705","TURKEY HEN",13.08
"662821","DURACELL 9V",20.99
"340761","/662821",-2
"4893","CREAM CHEESE",9.99
"26545","WHIP CREAM",10.29
"30669","BANANAS",1.99
"1048072","GREEK YOGURT",6.29
"2751","ACTIVE YEAST",6.99
,subtotal,102.6
,tax,1.78
,total,104.38


In the future, I might consider supporting:
https://github.com/GonzaloZiadi/CostcoWrapped
(I started with this latter one because it had a nice blog write-up
https://www.pathtosimple.com/is-costco-membership-worth-it#user-content-fn-6.
But it has a bug with coupons...possibly because Costco changed the format.)

CSV from second looks like: (has an extra field for date, ends without totals)
11/26/2024,37220,CHOC CHUNK,9.99
11/26/2024,692731,KS ORG EVOO,24.99
11/26/2024,97705,TURKEY HEN,13.08
11/26/2024,662821,DURACELL 9V,20.99
11/26/2024,R-340761,/6628,-212
11/26/2024,4893,CREAM CHEESE,9.99
11/26/2024,26545,WHIP CREAM,10.29
11/26/2024,30669,BANANAS,1.99
11/26/2024,1048072,GREEK YOGURT,6.29
11/26/2024,2751,ACTIVE YEAST,6.99
11/26/2024,TAX,TAX,1.78



In the future, might use beancount_import_sources.costco_receipt_source
https://github.com/ankurdave/beancount_import_sources/tree/main
which provides all the data in JSON format which it recovered from the receipt.
It has things I might be able to use such as the specific warehouse (to generate better matching credit card entry names),
the transaction dates, quantity, tax flag, secondary description.
I think it also may grab multiple receipts on the page.





QIF output is the bare minimum I need so I can import it without putting too much user-specific info.

!Type:CCard
D11-26-24
PCOSTCO WHSE
MCoupon Savings: $2.00
T-104.38
NWITHD
CX
LSplit
SGroceries
ECHOC CHUNK
$-9.99
SGroceries
EKS ORG EVOO
$-24.99
SGroceries
ETURKEY HEN
$-13.08
SHousehold
EDURACELL 9V
$-20.99
SHousehold/coupon
ECoupon for: DURACELL 9V
$2.00
SGroceries
ECREAM CHEESE
$-9.99
SGroceries
EWHIP CREAM
$-10.29
SGroceries
EBANANAS
$-1.99
SGroceries
EGREEK YOGURT
$-6.29
SGroceries
EACTIVE YEAST
$-6.99
STaxes:Sales
ESales Tax
$-1.78
^


Modification Notes:
I placed the categories in a separate categories.lua module so it would be easier to modify.
If you want to change the category names written to the QIF,
change the right-side string name to what you want in the m.categories table.

Figuring out what item goes to what category is a big keyword matching game.
m.item_to_category contains the mappings. Add or change things here.

The keywords are changed to uppercase before doing string.match against the item description.


Since the data separates coupons into their own entries, I preserve that.
I also added a tag called coupon to denote it is a coupon, so reports/searches can be done on coupons.
I didn't want to change the category because I felt it should be matched to the original item,
otherwise when you do big yearly reports, the report will overstate what you actually spent on e.g. Groceries,
and it will not be easy to see which coupons go with which categories.
TAGS add a second dimension.

--]==]



function parse_csv_receipt(full_file, entry_date_str, output_qif_file)
	local lpeg = require("lpeg")
	local categories = require("categories")

	
	local fh, err = io.open(full_file)
	if fh == nil then
		print(err)
		assert(false, "failed to open file")
		return nil
	end

	-- throw away description line
	local first_line = fh:read("*line")

	local receipt_array = {}

	do
		-- http://www.inf.puc-rio.br/~roberto/lpeg/lpeg.html#CSV
		local field = '"' * lpeg.Cs(((lpeg.P(1) - '"') + lpeg.P'""' / '"')^0) * '"' +
						lpeg.C((1 - lpeg.S',\n"')^0)
		--local record = field * (',' * field)^0 * (lpeg.P'\n' + -1)
		local record = lpeg.Ct(field * (',' * field)^0) * (lpeg.P'\n' + -1)

		for line in fh:lines() do
			local item = record:match(line)
			receipt_array[#receipt_array+1] = item
		end
	end
	fh:close()


	--[=[
	for k1,v1 in pairs(receipt_array) do
		local current_item = v1

		print("Entry #", k1)

		local output_str = "\t"
		for k2, v2 in pairs(current_item) do
			--print("Entry k1", ka1, "\titem key", k2, "item value", v2)
			--print("Entry k1", ka1, "\titem key", k2, "item value", v2)
			output_str = output_str .. v2 .. "\t"
		end
		print(output_str)
	end
	--]=]

	-- Clean up section:
	-- Last 3 lines are
	-- subtotal
	-- tax
	-- total
	-- Separate out these values

	assert(#receipt_array >= 3)

	local FIELD_ITEMID=1
	local FIELD_DESCRIPTION=2
	local FIELD_PRICE=3
	local totals_table
	do
		local array_end = #receipt_array
		totals_table = 
		{
			["total"] = receipt_array[array_end][FIELD_PRICE],
			["tax"] = receipt_array[array_end-1][FIELD_PRICE],
			["subtotal"] = receipt_array[array_end-2][FIELD_PRICE],
		}
	end
	--print("before remove #receipt_array", #receipt_array)
	table.remove(receipt_array)
	table.remove(receipt_array)
	table.remove(receipt_array)
	--print("after remove #receipt_array", #receipt_array)

	-- create a ID to item map so we can resolve coupon items that reference the id
	local itemid_map = {}
	for i=1,#receipt_array do
		local cur_entry = receipt_array[i]
		local cur_itemid = cur_entry[FIELD_ITEMID]
		assert(type(cur_itemid) == "string")
		--print("cur_itemid", cur_itemid)
		itemid_map[cur_itemid] = cur_entry
	end



	local output_prep_array = {}
	local coupon_total = 0.0
	for i=1,#receipt_array do
		local cur_entry = receipt_array[i]
		local cur_itemid = cur_entry[FIELD_ITEMID]
		local cur_description = cur_entry[FIELD_DESCRIPTION]
		local cur_price_str = cur_entry[FIELD_PRICE]
		assert(type(cur_itemid) == "string")
		assert(type(cur_price_str) == "string")

		local cur_price_num = tonumber(cur_price_str)
		local is_coupon = false
		if cur_price_num < 0.0 then

			local reference_id = string.match(cur_description, "^%/(%d+)$")
				or string.match(cur_description, "^#(%d+)$")
			-- 
			-- if we match something, this is a coupon referencing an item
			-- 340761	/662821	-2
			--print("in coupon match", cur_description)
			if reference_id then
				--print("got ref id", reference_id)
				assert(cur_price_num < 0.0)
				assert(type(reference_id) == "string")

				local ref_entry = itemid_map[reference_id]
				if ref_entry then
					is_coupon = true
					cur_description = "Coupon for: " .. ref_entry[FIELD_DESCRIPTION]

					coupon_total = coupon_total + cur_price_num
				else
					print("UNEXPECTED: Could not find item number: " .. reference_id .. " for coupon lookup")

				end

			-- I found another set of cases where a reference id is not used, but a keyword from the original item description is reused.
			-- But it is not necessarily the case the entire description string matches.
			-- It also seems to be preceded by a /
			-- So because this keyword contains search could accidentally hit the wrong item,
			-- instead of extracting "^/(%w+)$" to search,
			-- it seems that the coupon always immediately follows the item.
			-- Since we have ordered array, it seems better to just refer to the previous entry.
			else

				assert(i > 1)
				local prev_entry = receipt_array[i-1]
				is_coupon = true
				cur_description = "Coupon for: " .. prev_entry[FIELD_DESCRIPTION]
				coupon_total = coupon_total + cur_price_num



			end -- if reference_id

		end -- if cur_price_num < 0.0

			-- slow part: search for the category by running through all keywords in the categories.lua module.
		local item_to_cat_map = categories.item_to_category
		local found_category = ""
		for item, category in pairs(item_to_cat_map) do
			local item_upper = string.upper(item)
			if string.match(cur_description, item_upper) then
				found_category = category
				break
			end
		end

		if is_coupon then
			-- Using the TAG feature by appending /<tagname> to the category
			found_category = found_category .. "/coupon"
		end

		local output_entry =
		{
			["price"] = cur_price_num,
			["memo"] = cur_description,
			["category"] = found_category,
		}
		output_prep_array[#output_prep_array+1] = output_entry
		
	end


	-- final write to qif
	local output_lines = {}
	output_lines[1] = "!Type:CCard"
	output_lines[2] = "D" .. entry_date_str
	output_lines[3] = "PCOSTCO WHSE"

	-- In the json version, the sign always needs to be flipped, because of the refund/return case. But I forgot what happens in this version.
	-- I was always doing math.abs(coupon_total) here, but since I never tested/handled returns in this case,
	-- I'm not sure if I should always flip it like the json version.
	-- Since I don't have a good test, I'm preserving the abs for now.
	local abs_coupon_total = math.abs(coupon_total)
	local coupon_total_str = string.format("%.2f", abs_coupon_total)
	-- edge case: I've been seeing -0.00, so remove the negative sign.
	if coupon_total_str == "-0.00" then
		coupon_total_str = "0.00"
	end

	local total_amount = totals_table["total"]
	local percent_off = (abs_coupon_total / (total_amount + abs_coupon_total)) * 100.0
	--print("percent_off", percent_off)
	local percent_off_str = string.format("%.2f", percent_off)
	if percent_off_str == "-0.00" then
		percent_off_str = "0.00"
	end

	--output_lines[4] = "M" .. "Coupon Savings: $" .. coupon_total_str
	--output_lines[4] = "M" .. "Coupons: $" .. coupon_total_str
	output_lines[4] = "M" .. "Coupons: $" .. coupon_total_str .. " (" .. percent_off_str .. "% off)"

	output_lines[5] = "T-" .. totals_table["total"]

	output_lines[6] = "NWITHD"
	output_lines[7] = "CX"
	output_lines[8] = "LSplit"


	for i=1, #output_prep_array do
		local output_entry = output_prep_array[i]
		local category = output_entry["category"]
		local memo = output_entry["memo"]
		local price_num = -1.0 * output_entry["price"]
		local price_str = string.format("$%.2f", price_num)

		output_lines[#output_lines+1] = "S" .. category
		output_lines[#output_lines+1] = "E" .. memo
		output_lines[#output_lines+1] = price_str
	end


	output_lines[#output_lines+1] = "S" .. categories.categories["Taxes:Sales"]
	output_lines[#output_lines+1] = "E" .. "Sales Tax"
	output_lines[#output_lines+1] = "$-" .. totals_table["tax"]
	
	output_lines[#output_lines+1] = "^"


	local combined_str = table.concat(output_lines, "\n")
	--print(combined_str)
	
	print("Writing QIF to " .. output_qif_file)
	local fh, err = io.open(output_qif_file, "w")
	if fh == nil then
		print(err)
		assert(false, "failed to open file")
		return nil
	end
	fh:write(combined_str)
	fh:close()

end

--[[
print("#arg", #arg)
for k,v in pairs(arg) do
	print(k,v)
end
--]]

if #arg < 1 then
	print("Usage: lua " .. arg[0] .. " <costco_receipt.csv> [<output.qif>]")
	return 0
end

local input_csv_file = arg[1]

local entry_date_month, entry_date_day, entry_date_yy = string.match(input_csv_file, "%-(%d%d)-(%d%d)-%d%d(%d%d)")

local entry_date_str = string.format("%02d-%02d-%02d", entry_date_month, entry_date_day, entry_date_yy)

local output_qif_file = arg[2] or "costco-" .. entry_date_str .. ".qif"
parse_csv_receipt(input_csv_file, entry_date_str, output_qif_file)


return 0
