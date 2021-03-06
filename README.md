**Important**: The Rails 4 Gem Versions are **1.x**

# ArMailerRevised

[![Code Climate](https://codeclimate.com/github/Stex/ar_mailer_revised.png)](https://codeclimate.com/github/Stex/ar_mailer_revised)
[![Build Status](https://travis-ci.org/Stex/ar_mailer_revised.svg?branch=rails_4)](https://travis-ci.org/Stex/ar_mailer_revised)

[ArMailer](https://github.com/seattlerb/ar_mailer) is a great gem which allows you to store emails in your application's database and batch deliver
them later using a background task.

However, it was not compatible with newer versions of Rails and also lacking some of the functionality I needed in my applications.

In particular, I wanted to use 

* custom delivery dates in the future for delayed emails
* custom SMTP settings per email
* custom attributes directly in the email record to keep track of them

ArMailerRevised contains this functionality, currently only for Rails >= 4.

**Important**: ArMailerRevised does only deliver emails using SMTP, not a sendmail executable.

## Installation

Add this line to your application's Gemfile:

    gem 'ar_mailer_revised'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ar_mailer_revised
    
### Generating Files

ArMailerRevised needs a few things to work correctly:

1. A table in the database to store the email queue
2. An email model to create and access the email records
3. An initializer to set the gem configuration

All of them can be created using a generator:

    $ rails g ar_mailer_revised:install MODEL_NAME

If you don't specify a model name, the default name `Email` is used.
 
Please migrate your database after the migration was created.
If you need custom attributes (see below) in your email table, please 
add them to the migration before migrating.

    $ rake db:migrate

### Setting the delivery method

First of all, you have to set ActionMailer to use the gem's delivery method.
This can be done per environment or globally for the application using either

```ruby
config.action_mailer.delivery_method = :activerecord
```

or - not inside a configuration file

```ruby
ActionMailer::Base.delivery_method = :activerecord
```
    
### SMTP-Settings

ArMailerRevised accepts SMTP settings in the form ActionMailer::Base does.
Application wide settings have to be stored in ActionMailer::Base.smtp_settings.
Please have a look at [ActionMailer::Base](http://api.rubyonrails.org/classes/ActionMailer/Base.html)

The only difference here are additional TLS options as follows:

1. `:enable_starttls_auto` enables STARTTLS if the serves is capable to handle it
2. `:enable_starttls` forces the usage of STARTTLS, whether the server is capable of it or not
3. `:tls` forces the usage of TLS (SSL SMTP)

**Important**: These additional settings are in descending order, meaning that a higher importance
setting will override a less important setting.

`:openssl_verify_mode` is now supported and will be used if any of the above TLS options is enabled.

Below will be a growing list of demo SMTP settings for popular providers.

## Creating Emails

ArMailerRevised uses the normal ActionMailer::Base templates, so you can write
deliver-methods like you would for direct email sending.
On delivering, the email will be stored in the database and not being sent diretly.

```ruby
class TestMailer < ActionMailer::Base
  default from: 'from@example.com'

  def basic_email
    mail(to: 'basic_email@example.com', subject: 'Basic Email Subject', body: 'Basic Email Body')
  end
end
```
    
### Setting a custom delivery time

ArMailerRevised adds a new method to ActionMailer templates to customize
the resulting email record. One of them is +ar_mailer_delivery_time+.
This method sets a time which determines the earliest sending time for this email, 
in other words: If you set this time, the email won't be sent prior to it.

```ruby
def delayed_email
  ar_mailer_delivery_time Time.now + 2.hours
  mail(to: 'delayed_email@example.com', subject: 'Delayed Email Subject', :body => 'Delayed Email Body')
end
```
    
**Important**: It may happen that the Rails logging output of the generated mail may still contain
custom attributes (like the delivery time) in its header. This happens because ActionMailer will
log the email before actually delivering it. The generated email will **not** contain these headers any more.

### Setting custom SMTP settings

It is possible to set own SMTP settings for each email in the system which will then be used for delivery.
These settings may contain everything the global settings do (see above).

```ruby
def custom_smtp_email
  ar_mailer_smtp_settings({
    :address   => 'localhost',
    :port      => 25,
    :domain    => 'localhost.localdomain',
    :user_name => 'some.user',
    :password  => 'some.password',
    :authentication => :plain,
    :enable_starttls_auto => true
  })
    
  mail(to: 'custom_smtp_email@example.com', subject: 'Custom SMTP Email Subject', :body => 'Custom SMTP Email Body')
end
```

**Important**: As the mailer has to use the password to connect to the SMTP server, it is stored in the database in plain text!
If this means a security issue to you, please use only the global settings which are loaded from the environment and not stored in the database.

### Other custom attributes

It is possible to set custom attributes in the email record before it is saved, e.g.
to keep better track of emails (by adding an identifier of the reason the email was generated at all).

You can add custom attributes to the email table simply by altering the generated migration, e.g.

    t.integer 'a_number'
    
In the email delivering method, these attributes may then be filled with the actual data using the `ar_mailer_attribute` helper method:

```ruby
def custom_attribute_email
  ar_mailer_attribute :a_number, 42
  mail(to: 'custom_attribute_email@example.com', subject: 'Custom Attribute Email Subject', :body => 'Custom Attribute Email Body')
end
```
    
### Sending Emails

ArMailerRevised comes with an executable called `ar_sendmail` which can
be accessed from the application's root directory.

It accepts the argument `-h` (or `--help`), showing all available options.
If you call it without options, it will run a single batch sending in the foreground and exist afterwards.

There will be daemon functionality in the future (mostly to avoid loading the application environment
every single time emails are being sent), for now I suggest using a gem like [whenever](https://github.com/javan/whenever)
to run the executable every X minutes.

An entry in whenever's `schedule.rb` might look like this:

```ruby
every 5.minutes do
 command "cd #{path} && bundle exec ar_sendmail -c #{path} -e production -b 25 --log-file './log/ar_mailer.log' --log-level info"
end
```
    
### SMTP settings for common providers (to be extended)

GoogleMail:

    :address        => 'smtp.googlemail.com',
    :port           => 465,
    :domain         => 'googlemail.com',
    :user_name      => 'USERNAME@googlemail.com',
    :password       => 'SOME_PASSWORD',
    :authentication => :plain,
    :tls            => true
    
# Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
