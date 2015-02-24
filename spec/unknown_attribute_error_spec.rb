require 'spec_helper'

module UnknownAttributeErrorSpec
  describe "config#raise_error_on_unknown_attribute_select", :activerecord do
    class Blog < ActiveRecord::Base
      has_many :posts
    end

    it "doesn't raise errors when raise error is disabled (default)", :without_raise_error_on_unknown_attribute_select do
      blog = Blog.create title: "Blog 1"

      expect { Blog.with_datasource.datasource_select(:attribute_that_doesnt_exist).to_a }.to_not raise_error
    end

    it "raises errors when raising errors is enabled" do
      blog = Blog.create title: "Blog 1"

      expect { Blog.with_datasource.datasource_select(:attribute_that_doesnt_exist).to_a }.to raise_error(Datasource::Error)
    end
  end
end
