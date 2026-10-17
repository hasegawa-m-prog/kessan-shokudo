namespace :quiz do
  desc "確認済みの公開用15問を登録する（既存の問題・回答は削除しない）"
  task seed_public: :environment do
    if Rails.env.production? && ENV["CONFIRM_PUBLIC_QUESTIONS"] != "v1"
      abort "本番登録は内容・対象環境を確認し、CONFIRM_PUBLIC_QUESTIONS=v1 を指定してください"
    end
    require Rails.root.join("lib/public_learning_content")
    PublicLearningContent.load!
    puts "公開用15問の登録を確認しました。動作確認用の旧問題と回答は保持しています。"
  end

  desc "開発専用の動作確認用15問を登録する（公開教材ではありません）"
  task seed_demo: :environment do
    require Rails.root.join("lib/demo_learning_content")
    DemoLearningContent.load!
    puts "動作確認用データを登録しました。公開教材としての確認は未完了です。"
  end
end
