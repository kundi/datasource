require 'spec_helper'

module LoaderSpec
  describe "Loader" do
    class Comment < ActiveRecord::Base
      self.table_name = "comments"
      belongs_to :post
    end

    class Post < ActiveRecord::Base
      self.table_name = "posts"
      has_many :comments

      datasource_module do
        loader :newest_comment, group_by: :post_id, one: true do |collection|
          Comment.for_serializer.where(post_id: collection.ids)
            .group("post_id")
            .having("id = MAX(id)")
            .datasource_select(:post_id)
        end

        loader :newest_comment_text, array_to_hash: true do |collection|
          Comment.where(post_id: collection.ids)
            .group("post_id")
            .having("id = MAX(id)")
            .pluck("post_id, comment")
        end

        loader :ordered_comments, group_by: :post_id do |collection|
          Comment.for_serializer(CommentSerializer).where(post_id: collection.ids)
            .order("post_id, id desc")
            .datasource_select(:post_id)
        end

        computed :newest_comment, loaders: :newest_comment
        computed :newest_comment_text, loaders: :newest_comment_text
        computed :ordered_comments, loaders: :ordered_comments
      end

      def name_initials
        return unless author_first_name && author_last_name
        author_first_name[0].upcase + author_last_name[0].upcase
      end

      def newest_comment_text
        if _datasource_loaded
          _datasource_loaded[:newest_comment_text]
        else
          comments.order(:id).last.comment
        end
      end
    end

    class CommentSerializer < ActiveModel::Serializer
      attributes :id, :comment
    end

    class PostSerializer < ActiveModel::Serializer
      attributes :id, :title, :newest_comment, :newest_comment_text, :ordered_comments

      def newest_comment
        CommentSerializer.new(object._datasource_loaded[:newest_comment]).as_json
      end

      def ordered_comments
        ActiveModel::ArraySerializer.new(object._datasource_loaded[:ordered_comments]).as_json
      end

      def newest_comment_text
        object._datasource_loaded[:newest_comment_text]
      end
    end

    it "uses loader method" do
      post = Post.create! title: "First Post"
      2.times { |i| post.comments.create! comment: "Comment #{i+1}" }

      expect_query_count(4) do
        expect(ActiveModel::ArraySerializer.new(Post.all).as_json).to eq(
          [{:id=>1, :title=>"First Post", :newest_comment=>{"comment"=>{:id=>2, :comment=>"Comment 2"}}, :newest_comment_text=>"Comment 2", :ordered_comments=>[{:id=>2, :comment=>"Comment 2"}, {:id=>1, :comment=>"Comment 1"}]}]
        )
      end
    end

    class PostWithLoaded < ActiveRecord::Base
      self.table_name = "posts"
      has_many :comments, foreign_key: "post_id"

      datasource_module do
        loaded :newest_comment, group_by: :post_id, one: true do |collection|
          Comment.for_serializer.where(post_id: collection.ids)
            .group("post_id")
            .having("id = MAX(id)")
            .datasource_select(:post_id)
        end
      end

      def newest_comment
        comments.order(:id).last
      end
    end

    class PostWithLoadedSerializer < ActiveModel::Serializer
      attributes :id, :newest_comment

      def newest_comment
        CommentSerializer.new(object.newest_comment).as_json
      end
    end

    describe "Post#newest_comment_text" do
      it "uses loaded method when datasource is used" do
        2.times do
          post = PostWithLoaded.create! title: "First Post"
          2.times { |i| post.comments.create! comment: "Comment #{i+1}" }
        end

        expect_query_count(4) do
          expect(ActiveModel::ArraySerializer.new(PostWithLoaded.all).as_json).to eq(
            [
              {:id=>1, :newest_comment=>{"comment"=>{:id=>2, :comment=>"Comment 2"}}},
              {:id=>2, :newest_comment=>{"comment"=>{:id=>4, :comment=>"Comment 2"}}}
            ]
          )
        end
      end

      it "uses fallback logic when datasource is not used" do
        post = PostWithLoaded.create! title: "First Post"
        post.comments.create! comment: "Comment 1"
        expect_query_count(1) do
          expect(post.newest_comment.comment).to eq("Comment 1")
        end
      end
    end
  end
end
