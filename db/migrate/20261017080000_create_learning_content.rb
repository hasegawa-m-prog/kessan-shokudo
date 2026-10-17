class CreateLearningContent < ActiveRecord::Migration[8.1]
  def change
    create_table :industries do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :industries, :name, unique: true

    create_table :questions do |t|
      t.references :industry, null: false, foreign_key: true
      t.string :code, null: false
      t.integer :version, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.text :assumptions, null: false
      t.text :explanation, null: false
      t.datetime :published_at
      t.datetime :retired_at
      t.timestamps
    end
    add_index :questions, [ :code, :version ], unique: true
    add_index :questions, :code, unique: true, where: "published_at IS NOT NULL AND retired_at IS NULL", name: "one_active_question_version"
    add_check_constraint :questions, "version > 0", name: "positive_question_version"
    add_check_constraint :questions, "kind IN ('company_comparison', 'transaction')", name: "valid_question_kind"
    add_check_constraint :questions, "retired_at IS NULL OR (published_at IS NOT NULL AND retired_at >= published_at)", name: "valid_retirement"

    create_table :choices do |t|
      t.references :question, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :body, null: false
      t.boolean :is_correct, null: false, default: false
      t.timestamps
    end
    add_index :choices, [ :question_id, :position ], unique: true
    add_check_constraint :choices, "position BETWEEN 1 AND 3", name: "valid_choice_position"

    create_table :accounts do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.timestamps
    end
    add_index :accounts, [ :category, :name ], unique: true
    add_check_constraint :accounts, "category IN ('asset', 'liability', 'equity')", name: "valid_account_category"

    create_table :balance_sheets do |t|
      t.references :question, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :company_name, null: false
      t.text :business_description, null: false
      t.timestamps
    end
    add_index :balance_sheets, [ :question_id, :position ], unique: true
    add_check_constraint :balance_sheets, "position IN (1, 2)", name: "valid_sheet_position"

    create_table :balance_sheet_items do |t|
      t.references :balance_sheet, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.bigint :amount, null: false
      t.timestamps
    end
    add_index :balance_sheet_items, [ :balance_sheet_id, :account_id ], unique: true
    add_check_constraint :balance_sheet_items, "amount >= 0", name: "nonnegative_amount"
  end
end
