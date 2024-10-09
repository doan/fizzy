require "test_helper"

class BucketTest < ActiveSupport::TestCase
  test "revising access" do
    buckets(:writebook).accesses.revise granted: users(:david, :jz), revoked: users(:kevin)
    assert_equal users(:david, :jz), buckets(:writebook).users
  end
end
