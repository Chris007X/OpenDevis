class WorkItem < ApplicationRecord
  belongs_to :room
  belongs_to :work_category
  belongs_to :material
end
