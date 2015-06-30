
=begin
Qiitaのデータ
=end
class QiitaItem < ActiveRecord::Base
  def self.last_updated_at 
    item = QiitaItem.all.order("qiita_updated_at DESC").first()
    return item ?  DateTime.parse(item.qiita_updated_at.to_s()) : nil
  end
end

class GdriveSyncItem < ActiveRecord::Base
end

class EvernoteSyncItem < ActiveRecord::Base
end

