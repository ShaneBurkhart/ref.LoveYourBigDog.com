require "uri"
require "net/http"
require "digest/md5"
require "gibbon"

class UsersController < ApplicationController
  before_filter :skip_first_page, only: :new
  before_filter :check_captcha, only: :create
  #before_filter :handle_ip, only: :create

  def new
    @bodyId = 'home'
    @is_mobile = mobile_device?

    @user = User.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def create
    ref_code = cookies[:h_ref]
    email = params[:user][:email]
    @user = User.new(email: email)

    gibbon = Gibbon::Request.new(api_key: ENV["MAILCHIMP_API_KEY"])
    gibbon_updater = Gibbon::Request.new(api_key: ENV["MAILCHIMP_API_KEY"])

    @user.referrer = User.find_by_referral_code(ref_code) if ref_code

    if @user.save
      gibbon
        .lists(ENV["MAILCHIMP_LIST_ID"])
        .members(Digest::MD5.hexdigest(@user.email.downcase))
        .upsert(body: {
          email_address: @user.email,
          status: "subscribed",
          merge_fields: {
            ME_URL: "#{refer_a_friend_url}?me_ref=#{@user.referral_code}",
            REFER_URL: "#{r_url}?ref=#{@user.referral_code}",
            REFER_NUM: 0,
          }
        })

      if @user.referrer
        gibbon_updater
          .lists(ENV["MAILCHIMP_LIST_ID"])
          .members(Digest::MD5.hexdigest(@user.referrer.email.downcase))
          .upsert(body: {
            merge_fields: { REFER_NUM: @user.referrer.referrals.count }
          })
      end

      cookies[:h_email] = { value: @user.email }
      redirect_to '/refer-a-friend'
    else
      logger.info("Error saving user with email, #{email}")
      redirect_to root_path, alert: 'Something went wrong!'
    end
  end

  def refer
    @bodyId = 'refer'
    @is_mobile = mobile_device?
    ref_code = params[:me_ref]

    if ref_code
      referrer = User.find_by_referral_code(ref_code)
      cookies[:h_email] = { value: referrer.email } if referrer
    end

    @user = User.find_by_email(cookies[:h_email])

    respond_to do |format|
      if @user.nil?
        format.html { redirect_to root_path, alert: 'Something went wrong!' }
      else
        format.html # refer.html.erb
      end
    end
  end

  def refer_redirect
    # Cookie is automatically saved with before_filter
    redirect_to "http://woofandwhistleshop.com"
  end

  def policy
  end

  def redirect
    redirect_to root_path, status: 404
  end

  private

  def skip_first_page
    return if Rails.application.config.ended

    email = cookies[:h_email]
    if email && User.find_by_email(email)
      redirect_to '/refer-a-friend'
    else
      cookies.delete :h_email
    end
  end

  def check_captcha
    captcha_response = params['g-recaptcha-response']
    return if captcha_response.nil?

    post_data = {
      secret: ENV['RECAPTCHA_SECRET'],
      response: captcha_response,
      remoteip: request.remote_ip
    }

    resp = Net::HTTP.post_form(URI.parse('https://www.google.com/recaptcha/api/siteverify'), post_data)
    body = resp.body

    return redirect_to "/" if body["success"] == false
  end

  def handle_ip
    # Prevent someone from gaming the site by referring themselves.
    # Presumably, users are doing this from the same device so block
    # their ip after their ip appears three times in the database.

    address = request.env['HTTP_X_FORWARDED_FOR']
    return if address.nil?

    current_ip = IpAddress.find_by_address(address)
    if current_ip.nil?
      current_ip = IpAddress.create(address: address, count: 1)
    elsif current_ip.count > 2
      logger.info('IP address has already appeared three times in our records.
                 Redirecting user back to landing page.')
      return redirect_to root_path
    else
      current_ip.count += 1
      current_ip.save
    end
  end
end
