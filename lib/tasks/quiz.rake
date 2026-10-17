namespace :quiz do
  desc "開発専用の動作確認用15問を登録する（公開教材ではありません）"
  task seed_demo: :environment do
    require Rails.root.join("lib/demo_learning_content")
    DemoLearningContent.load!
    puts "動作確認用データを登録しました。公開教材としての確認は未完了です。"
  end
end
