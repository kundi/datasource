require 'spec_helper'

module PolymorphicAssociationSpec
  describe "Polymorphic associations" do
    class Comment < ActiveRecord::Base
      self.table_name = "comments"
      belongs_to :post, polymorphic: true
    end

    class Post < ActiveRecord::Base
      self.table_name = "posts"
      has_many :comments, as: :post
    end

    class PolyPost < ActiveRecord::Base
      self.table_name = "poly_posts"
      has_many :comments, as: :post
    end

    it "properly preloads the child records" do
      post = Post.create! title: "First Post"
      2.times { |i| post.comments.create! comment: "Comment #{i+1}" }

      expect_query_count(2) do
        Post.with_datasource.datasource_select(:id, comments: ["*"]).to_a
      end
    end

    it "properly preloads the parent records" do
      post = Post.create! title: "First Post"
      poly_post = PolyPost.create! post_title: "First Post"
      2.times { |i| post.comments.create! comment: "Comment #{i+1}" }
      1.times { |i| poly_post.comments.create! comment: "Comment #{i+1}" }

      expect_query_count(3) do
        Comment.with_datasource.datasource_select(:id, :post_id, :post_type, post: ["*"]).to_a
      end
    end
  end
end
