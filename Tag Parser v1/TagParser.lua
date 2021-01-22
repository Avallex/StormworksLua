
	--[[
	
		AVALLEX INDUSTRIES
		
		Name: Stormworks Object Tag Parsing API version 1.0
		Date: 22/01/2021
		Function:
		- Parses environment tag strings such as: "type=patreon,locations={workbench={-19,0,10},entrance={-11,-1,10},exit={-37,-1,10},balcony={-31,9,10}}"
		  into dictionary/table information.
		  
		- Current limitations:
		  - Will not parse spaces, so removes them
		  
		--// Please credit! //--
		  
	]]--
	
	local TagAPI = {
		TReferenceChar = '🔗'  			-- Character to reference parsed tables
	}
	
	function TagAPI.Parse(tagString)
		
		-- Reset control
		TagAPI.Copy = nil
		TagAPI.TIndexing = {}         	-- Stores indexes for table control characters
		TagAPI.TSequencing = {         	-- Stores all sequences for tables
			CDepth = 0,						-- Current table depth
			Pending = {},					-- Tables opened, pending to close
			Complete = {}					-- Tables with complete indexing
		}
		TagAPI.TCategories = {}       	-- Stores sequences by category (depth)
		TagAPI.Modifiers = {}         	-- Index modifiers based on changes to the original string
		TagAPI.ParsedTables = {}		-- Stores all string referenced parsed tables
		
		-- Remove spaces
		tagString = tagString:gsub(" ","");
	
		-- For either { or }
		for i, ControlCharacter in pairs({'{','}'}) do
		  
		  -- Copy the message
		  TagAPI.Copy = tagString
		  
		  -- While we can find a new character, store it's index
		  while true do
			local openIndex = string.find(TagAPI.Copy, ControlCharacter)
			if openIndex ~= nil then
			  table.insert(TagAPI.TIndexing, {Char = ControlCharacter, Index = openIndex + #TagAPI.TIndexing})
			  TagAPI.Copy = string.sub(TagAPI.Copy, 1, openIndex - 1) .. string.sub(TagAPI.Copy, openIndex + 1, #TagAPI.Copy)
			else
			  break;
			end
		  end
		end
		
		-- As long as we have the same number of { as } then continue
		if #TagAPI.TIndexing % 2 == 0 then
  
			-- Sort table by indexes
			table.sort(TagAPI.TIndexing, function(p1, p2) if p1.Index < p2.Index then return true; end end)
  
			-- Pair up start and end indexes using depth calculation
		    for index, indexData in ipairs(TagAPI.TIndexing) do
				if indexData.Char == '{' then
					TagAPI.TSequencing.CDepth = TagAPI.TSequencing.CDepth + 1
					TagAPI.TSequencing.Pending[TagAPI.TSequencing.CDepth] = indexData.Index
				elseif indexData.Char == '}' then
					table.insert(TagAPI.TSequencing.Complete, {
						Depth = TagAPI.TSequencing.CDepth,
						Start = TagAPI.TSequencing.Pending[TagAPI.TSequencing.CDepth],
						End = indexData.Index
					})
					TagAPI.TSequencing.Pending[TagAPI.TSequencing.CDepth] = nil
					TagAPI.TSequencing.CDepth = TagAPI.TSequencing.CDepth - 1
				end
			end
			
			-- Adjust end indexes based on the number of tables present
			for index, sequence in pairs(TagAPI.TSequencing.Complete) do
				sequence.End = sequence.End - #TagAPI.TSequencing.Complete
			end
	  
			-- Break sequence into depth categories
			for index, sequenceData in pairs(TagAPI.TSequencing.Complete) do
				if not TagAPI.TCategories[sequenceData.Depth] then
					TagAPI.TCategories[sequenceData.Depth] = {}
				end
				table.insert(TagAPI.TCategories[sequenceData.Depth], {sequenceData.Start, sequenceData.End})
			end
	  
			-- Sort categories inverse
			for index, category in ipairs(TagAPI.TCategories) do
				table.sort(category, function(p1,p2) if p1[1] > p2[1] then return true; end end)
			end
	  
			-- Update indexes based on the changes we've made to the original message
			function updateIndexes(startIndex, length)
				for catIndex, category in pairs(TagAPI.TCategories) do
					for seqIndex, sequence in pairs(category) do
						if sequence[1] > startIndex then
							sequence[1] = sequence[1] + length
						end
						if sequence[2] > startIndex then
							sequence[2] = sequence[2] + length
						end
					end
				end
			end
	  
			-- Parse sequences
			for catIndex = #TagAPI.TCategories, 1, -1 do
				for seqIndex, sequence in pairs(TagAPI.TCategories[catIndex]) do
				  
					-- Generate reference
					local Reference =  TagAPI.TReferenceChar .. TagAPI.Utilities.DictLength(TagAPI.ParsedTables) + 1
					TagAPI.ParsedTables[Reference] = {
						StartIndex = sequence[1],
						EndIndex = sequence[2],
						Content = string.sub(tagString, sequence[1] + 1, sequence[2] - 1)
					}

					-- Length change always starts at -2 as { and } were removed.
					local lengthChange = -2
					local lengthPrior = #tagString - 2
					tagString = string.sub(tagString, 1, sequence[1] - 1)..
					Reference..string.sub(tagString, sequence[2] + 1)

					-- Calculate length change 
					lengthChange = lengthChange - (lengthPrior - #tagString)

					-- Update indexes to account for different message length
					updateIndexes(sequence[1], lengthChange)
				  
				end
			end
	  
			-- Parse message
			function parseString(input)
				local Query = {
					ByComma = {},
					ByEquals = {},
					Dict = {}
				}
				for i in string.gmatch(input, "[^,]+") do
					table.insert(Query.ByComma, i)
				end
				for i, byCommaStr in pairs(Query.ByComma) do
					for i in string.gmatch(byCommaStr, "[^=]+") do
						table.insert(Query.ByEquals, i)
					end
				end
				if #Query.ByComma ~= #Query.ByEquals then
					for i = 1, #Query.ByEquals, 2 do
						Query.Dict[Query.ByEquals[i]] = Query.ByEquals[i + 1]
					end
				else
					Query.Dict = Query.ByComma
				end
				for index, value in pairs(Query.Dict) do
					local tableReference = string.match(value, TagAPI.TReferenceChar.."%d+")
					if tableReference then
						Query.Dict[index] = parseString(TagAPI.ParsedTables[tableReference].Content)
					end
				end
				return Query.Dict
			end
		
			return parseString(tagString);
			
		else
			server.announce('TagAPI','Tag format incorrect.')
		end
		
	end
	
	-- Gets length of dictionary
	TagAPI.Utilities = {}
	function TagAPI.Utilities.DictLength(dict)
		local counter = 0
		for _,_ in pairs(dict) do counter = counter + 1 end
		return counter;
	end