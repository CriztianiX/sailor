local db = require "sailor.db"
local helper = require "tests.helper"

describe("Testing mysql db module", function()
	it("should interpolate a query",function()
		db.connect()
		local res = db.interpolate_query("select * from ? where ? = ?",  "post", "id", 1)
		db.close()
		assert.is_equal("select * from 'post' where 'id' = 1", res)
	end)
  it("should run a query",function()
    local res = db.get_instance().query("SELECT COUNT(*) FROM post") 
    assert.is_equal("table", type(res))
  end)
end)