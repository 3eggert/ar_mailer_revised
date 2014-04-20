class CreateEmails < ActiveRecord::Migration
  def self.change
    create_table :emails do |t|
      t.string   'from'
      t.string   'to'

      #Timestamp for the last send attempt, 0 means, that there was no send attempt yet
      t.integer  'last_send_attempt', :default => 0

      #Mail body including headers
      t.text     'mail'

      #Custom delivery time, ArMailer won't send the email prior to this time
      t.datetime 'delivery_time'

      #Custom SMTP settings per email
      t.text     'smtp_settings'

      t.timestamps
    end
  end
end