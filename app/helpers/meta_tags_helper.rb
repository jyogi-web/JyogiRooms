module MetaTagsHelper
  # ページタイトルのデフォルト値を返す
  def page_title
    content_for(:title).presence || "Jyogi Rooms"
  end

  # ページディスクリプションのデフォルト値を返す
  def page_description
    content_for(:description).presence || "JyogiRoomsは部員による部員のための部室・鍵管理システムです。Discordと連携してセキュアでスムーズな管理を実現します。"
  end

  # OG画像URLのデフォルト値を返す（ベースURLを含む完全なURL）
  def page_og_image
    content_for(:og_image).presence || "#{request.base_url}/JyogiRoomsIcon.png"
  end

  # OG URLのデフォルト値を返す（現在のページの完全なURL）
  def page_og_url
    content_for(:og_url).presence || "#{request.base_url}#{request.fullpath}"
  end
end
