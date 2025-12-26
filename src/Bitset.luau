--!strict
--!native
--!optimize 2

local BITS_PER_WORD = 32

export type Bitset = {
	words: { number },
	wordCount: number,
}

local function create(initialCapacity: number?): Bitset
	local capacity = initialCapacity or 64
	local wordCount = math.ceil(capacity / BITS_PER_WORD)
	local words = table.create(wordCount, 0)

	for i = 1, wordCount do
		words[i] = 0
	end

	return {
		words = words,
		wordCount = wordCount,
	}
end

local function clone(bitset: Bitset): Bitset
	local newWords = table.create(bitset.wordCount)
	for i = 1, bitset.wordCount do
		newWords[i] = bitset.words[i]
	end

	return {
		words = newWords,
		wordCount = bitset.wordCount,
	}
end

local function ensureCapacity(bitset: Bitset, bitIndex: number)
	local requiredWords = math.ceil((bitIndex + 1) / BITS_PER_WORD)
	if requiredWords > bitset.wordCount then
		for i = bitset.wordCount + 1, requiredWords do
			bitset.words[i] = 0
		end
		bitset.wordCount = requiredWords
	end
end

local function set(bitset: Bitset, bitIndex: number)
	ensureCapacity(bitset, bitIndex)
	local wordIndex = math.floor(bitIndex / BITS_PER_WORD) + 1
	local bitOffset = bitIndex % BITS_PER_WORD
	bitset.words[wordIndex] = bit32.bor(bitset.words[wordIndex], bit32.lshift(1, bitOffset))
end

local function clear(bitset: Bitset, bitIndex: number)
	local wordIndex = math.floor(bitIndex / BITS_PER_WORD) + 1
	if wordIndex > bitset.wordCount then
		return
	end

	local bitOffset = bitIndex % BITS_PER_WORD
	bitset.words[wordIndex] = bit32.band(bitset.words[wordIndex], bit32.bnot(bit32.lshift(1, bitOffset)))
end

local function get(bitset: Bitset, bitIndex: number): boolean
	local wordIndex = math.floor(bitIndex / BITS_PER_WORD) + 1
	if wordIndex > bitset.wordCount then
		return false
	end

	local bitOffset = bitIndex % BITS_PER_WORD
	return bit32.band(bitset.words[wordIndex], bit32.lshift(1, bitOffset)) ~= 0
end

local function reset(bitset: Bitset)
	for i = 1, bitset.wordCount do
		bitset.words[i] = 0
	end
end

local function isEmpty(bitset: Bitset): boolean
	for i = 1, bitset.wordCount do
		if bitset.words[i] ~= 0 then
			return false
		end
	end

	return true
end

local function containsAll(bitset: Bitset, other: Bitset): boolean
	local maxWords = math.max(bitset.wordCount, other.wordCount)
	for i = 1, maxWords do
		local selfWord = bitset.words[i] or 0
		local otherWord = other.words[i] or 0
		if bit32.band(selfWord, otherWord) ~= otherWord then
			return false
		end
	end

	return true
end

local function containsAny(bitset: Bitset, other: Bitset): boolean
	local minWords = math.min(bitset.wordCount, other.wordCount)
	for i = 1, minWords do
		if bit32.band(bitset.words[i], other.words[i]) ~= 0 then
			return true
		end
	end

	return false
end

local function containsNone(bitset: Bitset, other: Bitset): boolean
	return not containsAny(bitset, other)
end

local function bitwiseAnd(a: Bitset, b: Bitset): Bitset
	local result = create(math.max(a.wordCount, b.wordCount) * BITS_PER_WORD)
	local minWords = math.min(a.wordCount, b.wordCount)
	for i = 1, minWords do
		result.words[i] = bit32.band(a.words[i], b.words[i])
	end

	return result
end

local function bitwiseOr(a: Bitset, b: Bitset): Bitset
	local maxWords = math.max(a.wordCount, b.wordCount)
	local result = create(maxWords * BITS_PER_WORD)
	for i = 1, maxWords do
		local aWord = a.words[i] or 0
		local bWord = b.words[i] or 0
		result.words[i] = bit32.bor(aWord, bWord)
	end

	return result
end

local function bitwiseXor(a: Bitset, b: Bitset): Bitset
	local maxWords = math.max(a.wordCount, b.wordCount)
	local result = create(maxWords * BITS_PER_WORD)
	for i = 1, maxWords do
		local aWord = a.words[i] or 0
		local bWord = b.words[i] or 0
		result.words[i] = bit32.bxor(aWord, bWord)
	end

	return result
end

local function equals(a: Bitset, b: Bitset): boolean
	local maxWords = math.max(a.wordCount, b.wordCount)
	for i = 1, maxWords do
		local aWord = a.words[i] or 0
		local bWord = b.words[i] or 0
		if aWord ~= bWord then
			return false
		end
	end

	return true
end

local function popCount(bitset: Bitset): number
	local count = 0
	for i = 1, bitset.wordCount do
		local word = bitset.words[i]
		while word ~= 0 do
			count += 1
			word = bit32.band(word, word - 1)
		end
	end

	return count
end

local function toHash(bitset: Bitset): string
	local parts = table.create(bitset.wordCount)
	for i = 1, bitset.wordCount do
		parts[i] = tostring(bitset.words[i])
	end
    
	return table.concat(parts, "|")
end

return {
	create = create,
	clone = clone,
	set = set,
	clear = clear,
	get = get,
	reset = reset,
	isEmpty = isEmpty,
	containsAll = containsAll,
	containsAny = containsAny,
	containsNone = containsNone,
	bitwiseAnd = bitwiseAnd,
	bitwiseOr = bitwiseOr,
	bitwiseXor = bitwiseXor,
	equals = equals,
	popCount = popCount,
	toHash = toHash,
	ensureCapacity = ensureCapacity,
	BITS_PER_WORD = BITS_PER_WORD,
}
