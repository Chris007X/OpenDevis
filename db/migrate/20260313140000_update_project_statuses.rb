class UpdateProjectStatuses < ActiveRecord::Migration[8.1]
  def up
    execute <<-SQL
      UPDATE projects SET status = 'in_progress' WHERE status = 'draft';
      UPDATE projects SET status = 'quote_requested' WHERE status = 'sent';
      UPDATE projects SET status = 'quote_received' WHERE status = 'accepted';
      UPDATE projects SET status = 'archived' WHERE status = 'rejected';
    SQL
  end

  def down
    execute <<-SQL
      UPDATE projects SET status = 'draft' WHERE status = 'in_progress';
      UPDATE projects SET status = 'sent' WHERE status = 'quote_requested';
      UPDATE projects SET status = 'accepted' WHERE status = 'quote_received';
      UPDATE projects SET status = 'rejected' WHERE status = 'archived';
    SQL
  end
end
