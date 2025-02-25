class DropCodeReviewNotesView < ActiveRecord::Migration[6.0]
  def up
    execute <<-SQL
      DROP VIEW code_review_notes;
    SQL
  end

  def down
    execute <<-SQL
      CREATE VIEW code_review_notes AS SELECT * from code_review_comments;
    SQL
  end
end
