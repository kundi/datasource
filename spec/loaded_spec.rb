require 'spec_helper'

module LoadedSpec
  describe "Loaded" do
    class Comment < ActiveRecord::Base
      self.table_name = "comments"
      belongs_to :post
    end

    class Post < ActiveRecord::Base
      self.table_name = "posts"
      has_many :comments

      datasource_module do
        loaded :newest_comment, group_by: :post_id, one: true
        loaded :newest_comment_text, from: :array
        loaded :ordered_comments, group_by: :post_id

        collection do
          def load_ordered_comments
            Comment.with_datasource.where(post_id: model_ids)
              .order("post_id, id desc")
              .datasource_select(:id, :comment, :post_id)
          end

          def load_newest_comment_text
            Comment.where(post_id: model_ids)
              .group("post_id")
              .having("id = MAX(id)")
              .pluck("post_id, comment")
          end

          def load_newest_comment
            Comment.with_datasource.where(post_id: model_ids)
              .group("post_id")
              .having("id = MAX(id)")
              .datasource_select(:id, :comment, :post_id)
          end
        end
      end

      def name_initials
        return unless author_first_name && author_last_name
        author_first_name[0].upcase + author_last_name[0].upcase
      end

      def newest_comment_text
        comments.order(:id).last.comment
      end
    end

    it "uses loaded method" do
      post = Post.create! title: "First Post"
      2.times { |i| post.comments.create! comment: "Comment #{i+1}" }

      expect_query_count(4) do
        posts = Post.with_datasource.datasource_select(:id, :title, :newest_comment, :newest_comment_text, :ordered_comments).to_a
        post = posts.first
        expect(post.title).to eq("First Post")

        expect(post.newest_comment.class).to eq(Comment)
        expect(post.newest_comment.comment).to eq("Comment 2")

        expect(post.newest_comment_text).to eq("Comment 2")

        expect(post.ordered_comments[0].comment).to eq("Comment 2")
        expect(post.ordered_comments[1].comment).to eq("Comment 1")
      end
    end

    class PostWithLoaded < ActiveRecord::Base
      self.table_name = "posts"
      has_many :comments, foreign_key: "post_id"

      datasource_module do
        loaded :newest_comment, group_by: :post_id, one: true

        collection do
          def load_newest_comment
            Comment.with_datasource.where(post_id: model_ids)
              .group("post_id")
              .having("id = MAX(id)")
              .datasource_select(:id, :comment, :post_id)
          end
        end
      end

      def newest_comment
        comments.order(:id).last
      end
    end

    describe "Post#newest_comment_text" do
      it "uses loaded method when datasource is used" do
        2.times do
          post = PostWithLoaded.create! title: "First Post"
          2.times { |i| post.comments.create! comment: "Comment #{i+1}" }
        end

        expect_query_count(2) do
          posts = PostWithLoaded.with_datasource.datasource_select(:id, :newest_comment).to_a

          expect(posts[0].newest_comment.class).to eq(Comment)
          expect(posts[0].newest_comment.comment).to eq("Comment 2")

          expect(posts[1].newest_comment.class).to eq(Comment)
          expect(posts[1].newest_comment.comment).to eq("Comment 2")

          expect(posts[0].id).to_not eq(posts[1].id)
          expect(posts[0].newest_comment.id).to_not eq(posts[1].newest_comment.id)
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
