# ArMailerRevised

ArMailer is a great gem that allows you to store emails in your application's database and batch deliver
them later using a background task.

However, it was not compatible with newer versions of Rails and also lacking some of the functionality
I needed in my applications.

Especially, I wanted to set 

* custom delivery dates in the future for delayed emails
* custom SMTP settings per email
* custom attributes directly in the email record to keep track of them

ArMailerRevised contains this functionality, currently only for Rails >= 4.

## Installation

Add this line to your application's Gemfile:

    gem 'ar_mailer_revised'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ar_mailer_revised

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
