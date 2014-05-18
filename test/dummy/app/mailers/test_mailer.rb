class TestMailer < ActionMailer::Base
  default from: 'from@example.com'

  def basic_email
    mail(to: 'basic_email@example.com', subject: 'Basic Email Subject', body: 'Basic Email Body')
  end

  def delayed_email
    ar_mailer_delivery_time Time.now + 2.hours
    mail(to: 'delayed_email@example.com', subject: 'Delayed Email Subject', :body => 'Delayed Email Body')
  end

end
