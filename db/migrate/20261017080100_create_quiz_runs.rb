class CreateQuizRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :quiz_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :industry, foreign_key: true
      t.string :kind, null: false
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps
    end
    add_check_constraint :quiz_runs, "kind IN ('quiz', 'review')", name: "valid_run_kind"
    create_table :quiz_run_questions do |t|
      t.references :quiz_run, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end
    add_index :quiz_run_questions, [ :quiz_run_id, :question_id ], unique: true
    add_index :quiz_run_questions, [ :quiz_run_id, :position ], unique: true
    add_check_constraint :quiz_run_questions, "position BETWEEN 1 AND 5", name: "valid_run_position"
    create_table :answers do |t|
      t.references :quiz_run_question, null: false, foreign_key: true, index: { unique: true }
      t.references :choice, null: false, foreign_key: true
      t.datetime :answered_at, null: false
      t.timestamps
    end
  end
end
