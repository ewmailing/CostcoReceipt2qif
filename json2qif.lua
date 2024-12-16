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



This uses the json output from beancount_import_sources.costco_receipt_source
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



local function ParseHelper_ToInteger(param)
	local converted_param, error_string = tonumber(param)
	if not converted_param then
		return nil, "argument: '" .. tostring(param) .. "' must be a number."
	end
	if converted_param ~= math.floor(converted_param) then
		return nil, "argument: '" .. tostring(param) .. "' must be an integer."
	end

	return converted_param
end

local function ConfigureArgumentParser()

	local argparse = require("argparse")


	local program_path_and_name = arg[0]
--	dprint("arg[0]: ", arg[0])
--	dprint("package.cpath: ", package.cpath)

	local parser = argparse(
		{
			name = arg[0], -- use global arg to get name of executable
			description = "Generates a .qif from Costco receipt json data.",
			epilog = "Example Usage:\n"
				.. program_path_and_name
				.. " ~/Downloads/costco-2024-12-13T06_09_56.747Z.json\n"

		}
	)
	-- parser:option("--prefdir"):args("?")
	
	parser:option("--recent -r")
		:description("Only use the N most recent receipts.")
		:convert(ParseHelper_ToInteger)
		-- default is to omit parameter, which does all.



	--parser:argument("input_and_output_files", "Input .json file, and optional target .qif file.")
	parser:argument("input_file", "Input .json file")
		:args(1)
	parser:argument("output_file", "Output .qif file")
		:args("?")
	return parser
end

-- wrapped function to optionally use lpeg if available.
local function wrapped_json_decode(all_data)

	local haslpeg, lpeg = pcall(require,"lpeg")
	local json
	if haslpeg then
--		lpeg.locale(lpeg)
		json = require("dkjson").use_lpeg()
	else
		print("Notice: LPEG not detected. Using fallback mode, which may be slower.")
		json = require("dkjson")
	end

	local decoded_data = json.decode(all_data)

		--assert(decoded_data, "json.decode failed on the input file")



	return decoded_data
end



function parse_json_receipt(full_file, output_qif_file, recent_amount)
	local categories = require("categories")

	
	local all_receipts_array = nil
	do
		local fh, err = io.open(full_file)
		if fh == nil then
			print(err)
			assert(false, "failed to open file")
			return nil
		end
		local file_data = fh:read("*all")
		fh:close()

		all_receipts_array = wrapped_json_decode(file_data)
		--file_data = nil
		--fh = nil
	end


	-- TODO: Consider parallalizing because each receipt in the array should be independent of all others.
	
	local qif_receipt_array = {}

	local end_range = #all_receipts_array
	if recent_amount > -1 then
	
		end_range = math.min(recent_amount, #all_receipts_array)

	end

	for current_receipt_index=1, end_range do

		local current_receipt = all_receipts_array[current_receipt_index]

		local item_array = current_receipt["itemArray"]


		-- These are for sanity checking, to make sure all the items add up to the total amount that is reported for the receipt.
		-- check_running_total1 adds up all the item prices as reported
		local check_running_total1 = 0.0
		-- check_running_total2 adds up all the item prices after they may have been divided up by quantities (price per unit).
		-- This one might show rounding errors.
		local check_running_total2 = 0.0


		--[=[
		for k1,v1 in pairs(item_array) do
			local current_item = v1

			print("Entry #", k1)

			local output_str = "\t"
			for k2, v2 in pairs(current_item) do
				--print("Entry k1", ka1, "\titem key", k2, "item value", v2)
				--print("Entry k1", ka1, "\titem key", k2, "item value", v2)
				--output_str = output_str .. v2 .. "\t"
				output_str = output_str .. k2 .. ":" .. v2 .. ",\t"
			end
			print(output_str)
		end
		--]=]


		-- create a ID to item map so we can resolve coupon items that reference the id
		local itemid_map = {}
		for i=1,#item_array do
			local cur_entry = item_array[i]
			local cur_itemid = cur_entry["itemNumber"]
			assert(type(cur_itemid) == "string")
			--print("cur_itemid", cur_itemid)
			itemid_map[cur_itemid] = cur_entry
		end



		local output_prep_array = {}
		local coupon_total = 0.0
		for i=1,#item_array do
			local cur_entry = item_array[i]
			local cur_itemid = cur_entry["itemNumber"]
			local cur_description = cur_entry["itemDescription01"]
	--		local cur_price_str = cur_entry["amount"]
			local cur_price_num = cur_entry["amount"]
	--		local cur_unit_str = cur_entry["unit"] --quantity
			local cur_unit_num = cur_entry["unit"] --quantity
			local cur_abs_unit_num = math.abs(cur_unit_num)

			--print("cur_price_str", cur_price_str)
			assert(type(cur_itemid) == "string", "expecting string for cur_itemid")
	--		assert(type(cur_price_str) == "string")
	--		assert(type(cur_unit_str) == "string")
			assert(type(cur_price_num) == "number", "expecting number for cur_price_num")
			assert(type(cur_unit_num) == "number", "expecting number for cur_unit_num")
			assert(type(cur_description) == "string", "expecting string for cur_description")

	--		local cur_price_num = tonumber(cur_price_str)
	--		local cur_unit_num = tonumber(cur_unit_str)
	--

			-- I think we get unit==0 in cases where there is a cancelled purchase
			-- i.e. the cashier may have accidentally entered the wrong item and then voided it.
			if cur_unit_num == 0 then
				assert(cur_price_num == 0.0, "price should also be 0 in the unit==0 (voided) case")
				goto next_item_in_item_array
			end

			check_running_total1 = check_running_total1 + cur_price_num

			local is_coupon = false

			-- COUPON check:
			-- If the first character of the description starts with a / or #
			-- it seems to be a coupon.
			-- I found out the hard way that testing for negative price or negative units is wrong
			-- because Costco will flip the signs for returning items.
			local first_char = string.sub(cur_description, 1, 1)
			if first_char == "/" or first_char == "#" then

				local reference_id = string.match(cur_description, "^%/(%d+)$")
					or string.match(cur_description, "^%#(%d+)$")

				-- I found a case where the description was /GLOVE, but the frenchItemDescription had the /refid
				if reference_id == nil then
					local french_description = cur_entry["frenchItemDescription1"]
					if french_description then
						reference_id = string.match(french_description, "^%/(%d+)$")
							or string.match(french_description, "^%#(%d+)$")
					end
				end
				-- 
				-- if we match something, this is a coupon referencing an item
				-- 340761	/662821	-2
				--print("in coupon match", cur_description)
				if reference_id then
					--print("got ref id", reference_id)
					assert(type(reference_id) == "string")

					local ref_entry = itemid_map[reference_id]
					if ref_entry then
						is_coupon = true
						cur_description = "Coupon for: " .. ref_entry["itemDescription01"]

						coupon_total = coupon_total + cur_price_num
					else
						print("UNEXPECTED: Could not find item number: " .. reference_id .. " for coupon lookup")
						cur_description = "Coupon"
						coupon_total = coupon_total + cur_price_num

					end

				-- I found another set of cases where a reference id is not used, but a keyword from the original item description is reused.
				-- But it is not necessarily the case the entire description string matches.
				-- It also seems to be preceded by a /
				-- So because this keyword contains search could accidentally hit the wrong item,
				-- instead of extracting "^/(%w+)$" to search,
				-- it seems that the coupon always immediately follows the item.
				-- Unforunately, unlike the CSV files I was looking at, the coupon doesn't seem to directly follow the item.
				-- So we can't just look at the previous.
				else

					local did_find_ref = false
					--print("cur_description", cur_description)
					local reference_keyword = string.match(cur_description, "^%/(%w+)")
					--print("reference_keyword", reference_keyword)

					-- Drat, I found a case where an item starts with #, e.g. #10 SEC ENVL
					-- It's probably why they started using /
					-- So if reference_keyword is nil, skip out and try to go on as this is not a coupon.
					if reference_keyword then
						for j=1,#item_array do
							if i ~= j then
								local ref_entry = item_array[j]
								local ref_description = ref_entry["itemDescription01"]
						
								-- print("j=" .. j, "ref_description", ref_description)

								-- need to use string.find with 4th parameter to disable magic characters
								if string.find(ref_description, reference_keyword, 1, true) then
	--							if string.match(ref_description, reference_keyword) then
									is_coupon = true
									cur_description = "Coupon for: " .. ref_entry["itemDescription01"]
									coupon_total = coupon_total + cur_price_num
									did_find_ref = true
									break
								end
							end
						end

						if not did_find_ref then
							print("WARNING: Could not find item for coupon cur_description")

							cur_description = "Coupon for: " .. cur_description
							coupon_total = coupon_total + cur_price_num
							is_coupon = true
						end
					end -- if reference_keyword


				end -- if reference_id

			end -- first_char == "/" or first_char == "#" then

			-- slow part: search for the category by running through all keywords in the categories.lua module.
			local item_to_cat_map = categories.item_to_category
			local found_category = ""
			local did_find_category = false
			for item, category in pairs(item_to_cat_map) do
				local item_upper = string.upper(item)
				--if string.match(cur_description, item_upper) then
				-- need to use string.find with 4th parameter to disable magic characters
				if string.find(cur_description, item_upper, 1, true) then
					found_category = category
					did_find_category = true
					break
				end
			end

			if not did_find_category then
				print("WARNING: Did not find category for ", cur_itemid, cur_description, current_receipt.transactionDate)
			end

			if is_coupon then
				-- Using the TAG feature by appending /<tagname> to the category
				found_category = found_category .. "/coupon"


				-- It appears coupons have unit<=-1
				-- (unless you are returning an item, and all the signs get flipped)
				--[=[
				print("cur_unit_num", cur_unit_num, cur_description)
				assert(cur_unit_num <= -1, "Coupons have unit == -1")
				--]=]
			end


			-- For multiple units (quantity), I will create extra entries for each unit.
			-- The intention is to help make it easier to track price changes over time for an item.
			-- Multiple quantities with a combined price ofuscates the unit price.
			-- And QIF does not support quantity + price-per-unit.
			-- I considered putting this info in the memo,
			-- but that would make doing further analysis really hard.
			-- NOTE: It appears coupons get marked with negative units. 
			-- I found a case where I bought 4 units of an item, and there were -4 units for the coupon.
			-- So going with the flow, the coupons will also be duplicated for multiple units.
		
			--[[
			if is_coupon and cur_unit_num > 1 then
				print("FOUND COUPON with unit > 1", cur_description)
			end
			--]]

			--print("cur_unit_num", cur_unit_num, cur_description)
			local entry_price = cur_price_num

			if cur_abs_unit_num > 1 then
				-- FIXME: What about rounding errors?
				-- denom should abs
				local price_per_unit = cur_price_num / cur_abs_unit_num
				entry_price = price_per_unit
				-- attempt to round better...assumes this value will be truncated when writing to the qif
				-- This actually created a problem, not help.
				--entry_price = price_per_unit + 0.005
			end

			local output_entry =
			{
				["price"] = entry_price,
				["memo"] = cur_description,
				["category"] = found_category,
			}

			for j=1, cur_abs_unit_num do
				output_prep_array[#output_prep_array+1] = output_entry
			end

			
			::next_item_in_item_array::
		end




		local entry_date_yy, entry_date_month, entry_date_day = string.match(current_receipt.transactionDate, "%d%d(%d%d)-(%d%d)-(%d%d)")
		local qif_date_str = string.format("%02d-%02d-%02d", entry_date_month, entry_date_day, entry_date_yy)

		-- Trying to match the name that Citi Costco Visa generates in its transaction names
		local payee_name = "COSTCO WHSE #"
			-- I found a business center with 3 digits, and Citi puts a leading 0 in front of it to make 4 digits
			.. string.format("%04d", tonumber(current_receipt.warehouseNumber))
			.. "        " -- seems to be 8 spaces
			.. current_receipt.warehouseCity

--		print("payee", payee_name)

		local total_amount = current_receipt.total
		local tax_amount = current_receipt.taxes
		assert(type(total_amount) == "number", "expecting number for total_amount")
		assert(type(tax_amount) == "number", "expecting number for tax_amount")
		local is_refund = false
		if total_amount < 0.0 then
			is_refund = true
		end

		-- write to qif
		local output_lines = {}
		-- Will insert the !Type: at the very end since there are multiple receipts
--		output_lines[1] = "!Type:CCard"
		output_lines[1] = "D" .. qif_date_str
		output_lines[2] = "P" .. payee_name
		-- always need to flip sign
		local coupon_total_str = string.format("%.2f", -coupon_total)
		-- edge case: I've been seeing -0.00, so remove the negative sign.
		if coupon_total_str == "-0.00" then
			coupon_total_str = "0.00"
		end
		--output_lines[3] = "M" .. "Coupon Savings: $" .. coupon_total_str
		output_lines[3] = "M" .. "Coupons: $" .. coupon_total_str


		-- always need to flip sign
		-- for charge, our costco receipt is positive, but qif must be neg.
		-- for refund, our costco receipt is negative, but qif must be pos.
		output_lines[4] = "T" .. tostring(-total_amount)

		if is_refund then
			output_lines[5] = "NDEP"
		else
			output_lines[5] = "NWITHD"
		end

--		output_lines[6] = "CX"
		output_lines[6] = "LSplit"


		for i=1, #output_prep_array do
			local output_entry = output_prep_array[i]
			local category = output_entry["category"]
			local memo = output_entry["memo"]
			-- always need to flip sign
			local price_num = -1.0 * output_entry["price"]
			local price_str = string.format("$%.2f", price_num)

			output_lines[#output_lines+1] = "S" .. category
			output_lines[#output_lines+1] = "E" .. memo
			output_lines[#output_lines+1] = price_str

			-- sanity checking: convert back the price_str into a number and see if we detect any rounding errors
			--print(price_str)
			local back_to_num_str = string.match(price_str, "^%$(%-*%d+%.%d%d)$")
			--print(back_to_num_str)
			local back_to_num = tonumber(-back_to_num_str)
			check_running_total2 = check_running_total2 + back_to_num 
		end



		output_lines[#output_lines+1] = "S" .. categories.categories["Taxes:Sales"]
		output_lines[#output_lines+1] = "E" .. "Sales Tax"
		-- always need to flip sign
		output_lines[#output_lines+1] = "$" .. tostring(-tax_amount)
		
		output_lines[#output_lines+1] = "^"


		check_running_total1 = check_running_total1 + tax_amount
		check_running_total2 = check_running_total2 + tax_amount

		-- Final santity check to make sure values add up.
		-- Converting to string because I don't want hidden trailing decimals to yield false floating comparisons.
		local total_amt_str = string.format("%.2f", total_amount)
		local check_running_total1_str = string.format("%.2f", check_running_total1)
		local check_running_total2_str = string.format("%.2f", check_running_total2)
		local failed_check1 = false
		if total_amt_str ~= check_running_total1_str then
			print("WARNING: Computed1 amounts for receipt " .. current_receipt.transactionDate .. " do not match. Expected: " .. total_amt_str .. ", but got " .. check_running_total1_str)
			failed_check1 = true
		end
		if total_amt_str ~= check_running_total2_str then
			if failed_check1 then
				print("WARNING: Computed2 amounts for receipt " .. current_receipt.transactionDate .. " do not match. Expected: " .. total_amt_str .. ", but got " .. check_running_total2_str)
			else
				print("WARNING: It appears a rounding error has been created by itemizing quantities for receipt " .. current_receipt.transactionDate .. " do not match. Expected: " .. total_amt_str .. ", but got " .. check_running_total2_str)
			end
		end



		local combined_str = table.concat(output_lines, "\n")
		--print(combined_str, "\n")
		-- save this qif receipt in array of all qif receipts which will be flattened later
		qif_receipt_array[#qif_receipt_array+1] = combined_str

		-- ::end_each_receipts_loop::
		
	end -- for current_receipt_index=1, #all_receipts_array do
	-- [=[
	if #qif_receipt_array > 0 then

		if not output_qif_file then

			local first_receipt = all_receipts_array[1]
			local transaction_date = first_receipt.transactionDate
			output_qif_file = "costco_" .. transaction_date .. ".qif"
		end


		print("Writing QIF to " .. output_qif_file)
		
		table.insert(qif_receipt_array, 1, "!Type:CCard")

		local combined_str = table.concat(qif_receipt_array, "\n")
		local fh, err = io.open(output_qif_file, "w")
		if fh == nil then
			print(err)
			assert(false, "failed to open file")
			return nil
		end
		fh:write(combined_str)
		fh:close()
	else
		print("No receipts to write out. Ending program.")
	end
	--]=]

end





local arg_parser = ConfigureArgumentParser()
--print(arg_parser:get_usage())

local parsed_arguments = arg_parser:parse()

local input_file = parsed_arguments["input_file"]
local output_file = parsed_arguments["output_file"]
local recent_amount = parsed_arguments["recent"]
--print("input_file", input_file)
--print("output_file", output_file)
--print("recent_amount", recent_amount)

if not recent_amount then
	recent_amount = -1
elseif recent_amount < 0 then
	print("NOTE: --recent with negative numbers is interpreted as disabled.")
end

--[[
local entry_date_yy, entry_date_month, entry_date_day = string.match(input_csv_file, "%d%d(%d%d)-(%d%d)-(%d%d)")

local entry_date_str = string.format("%02d-%02d-%02d", entry_date_month, entry_date_day, entry_date_yy)

local output_qif_file = arg[2] or "costco-" .. entry_date_str .. ".qif"
--]]
parse_json_receipt(input_file, output_file, recent_amount)

return 0

