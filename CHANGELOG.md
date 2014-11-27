Version 1.0.2
-------------

- Remove custom SMTP settings on SMTP SyntaxErrors.
  This makes more sense than simply trying to re-deliver them
  in the next batch as it will most likely still be bad syntax.
- Emails with Syntax or Authentication errors without custom SMTP
  settings are now handled by adjusting their last send attempt.
  This causes them to go to the end of the sending queue where they
  will either be deleted after some time or - hopefully - eventually
  sent when the developer corrects his application's SMTP settings.
