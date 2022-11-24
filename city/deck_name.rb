module DeckName
  Known = [
    ["LiLgLn-TnGmGw-gHLLn6", "アルセウスVSTAR"],
    ["8x8x48-QzM65x-cxxGKx", "アルセウスVSTAR"], # うらこうさく
    ["gngLiL-WKQgyP-gLnLNL", "アルセウスVSTAR"], # うらこうさく
    ["NNLHQL-3Saux2-nLinnL", "オリジンパルキアVSTAR"],
    ["xGDcY8-9Atco7-xDx8a8", "オリジンパルキアVSTAR"],
    ["6gLnig-A7WC7T-QgLngn", "オリジンパルキアVSTAR"],
    ["MyypyX-yR2Rbd-2UMSMM", "キュレム パルキア"],
    ["kFVkFF-YMbSeC-kkFFkV", "キュレム パルキア"],
    ["MMRMM2-UrIGQG-p3XMyy", "ギラティナ そらをとぶピカチュウ アルセウス"],
    ["XXMp3y-RZNFZT-pyXy2y", "ギラティナ アルセウス"],
    ["8Yaxcx-FSlPpQ-8x8xcx", "ギラティナVSTAR"],
    ["dV5kfV-dCe4mL-VdkV51", "ジュラルドン アルセウス"],
    ["Vv1vkV-xfzQQr-kVkFkV", "ジュラルドン アルセウス"],
    ["pMpyyp-y6qr3X-yMypUy", "ジュラルドン アルセウス"],
    ["VfkkV5-QwzM1B-Vkbv1V", "ジュラルドン アルセウス"],
    ["bkVkkk-L1Gt6e-fFkFfb", "ジュラルドン アルセウス"],
    ["LnnnLL-xxFlSc-n6LinH", "ジュラルドン アルセウス"],
    ["yyMyMM-Z5JEyZ-M2ypUX", "ゾロアーク"],
    ["yyyM2M-Zgfdkb-SME22M", "ゾロアーク"], #ヒスイ ゾロアーク
    ["VkFvkw-TASUx9-VVVkVV", "ゾロアークVSTAR"],
    ["kFkkFV-fJIhh2-kf5k1V", "マタドガス ムゲンダイナVMAX"],
    ["nLnggg-bzZ5J7-HgLnHH", "ミュウVMAX"],
    ["niLLPL-tyJQe1-gnnLQQ", "ミュウVMAX"],
    ["D8848J-NRLceF-xc448x", "ミュウVMAX"],
    ["DxD8c8-Rh4mtx-xJxcc4", "ミュウVMAX"],
    ["FkkFvk-UK4x2y-VVFFkw", "ミュウツーV-UNION"],
    ["L9LLnN-UOVCCT-Lgn6gL", "ムゲンダイナVMAX"],
    ["HNLNnn-oKw2Uo-nnLgnn", "ムゲンダイナVMAX"],
    ["x8cx8x-7lAAIA-88KG84", "ルギアVSTAR"],
    ["yy2M2p-L5KX6A-ySSpMX", "ルギア そらをとぶピカチュウ"],
    ["c8xxYc-ldylN3-c88888", "ルナトーン ソルロック"],
    ["F5VFbV-Wrub8f-kk5FVk", "レジエレキVMAX クワガノン"],
    ["yMM2yM-iKTV6Y-pMUpp3", "レジエレキVMAX クワガノン"],
    ["yMMUyM-K1LaWB-yyypXy", "レジエレキVMAX クワガノン"],
    ["yMpypU-VKlvc8-pyyM2M", "レジギガス"],
    ["gnQLHg-1AaruO-nnngnn", "レジギガス"],
    ["8K8xxx-w7qMXf-8x88x8", "ロストカイオーガ"],
    ["n9ggng-2Y4KdR-N6LnLn", "ロストバレット"],
    ["8xxx8Y-r1RHlR-4cG8JY", "ロストバレット"],
    ["MMyMXy-gxnyak-yMXyM3", "ロストバレット"],
    ["Jc84cJ-QgVka6-DD8x8K", "ロストバレット"],
    ["VkVFFf-BIdt7p-kk5V5F", "ロストバレット"],
    ["fVfFkk-KWWo4B-VkvVkF", "ロストバレット"], #レシラム
    ["FkwVwk-CpUB9b-VFkVfk", "ロトムVSTAR"]
  ]


  module_function
  def guess(world, deck)
    cos, name = Known.map {|known|
      [world.cos(known.first, deck).clamp(0,1.0), known.last]
    }.max
    pp [cos, deck, name] if cos < 0.9
    name
  end
end

if __FILE__ == $0
  pp DeckName::Known.sort_by {|x| x.last}
end