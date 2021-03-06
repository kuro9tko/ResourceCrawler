# == Schema Information
#
# Table name: datapool_keywords
#
#  id         :bigint(8)        not null, primary key
#  keyword    :string(255)      not null
#  uuid       :string(255)      not null
#  used_count :integer          default(0), not null
#  options    :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_datapool_keywords_on_keyword  (keyword) UNIQUE
#  index_datapool_keywords_on_uuid     (uuid) UNIQUE
#

class Datapool::Keyword < ApplicationRecord
  has_many :website_keywords, class_name: 'Datapool::WebsiteKeyword', primary_key: :uuid, foreign_key: :datapool_keyword_uuid
  has_many :resource_keywords, class_name: 'Datapool::ResourceKeyword', primary_key: :uuid, foreign_key: :datapool_keyword_uuid
end
