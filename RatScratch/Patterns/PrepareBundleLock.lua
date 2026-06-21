local MetaService = require("RatScratch.Services.MetaService")

local function PrepareBundleLock(lock, meta)
	lock = MetaService.clone(lock)

	for i = 2, #lock do
		local lockMeta = lock[i]

		local childMeta
		for j = 2, #meta do
			if meta[j].name == lockMeta.name then
				childMeta = meta[j]
				break
			end
		end

		if childMeta and childMeta.url:match("(.*).rsmeta") then
			local pendingLockMeta = MetaService.clone(lockMeta)
			pendingLockMeta.version = childMeta.version

			lock[i] = pendingLockMeta
		end
	end

	return lock
end

return PrepareBundleLock
