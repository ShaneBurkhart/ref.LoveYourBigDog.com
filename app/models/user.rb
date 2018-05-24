require 'users_helper'

class User < ActiveRecord::Base
  belongs_to :referrer, class_name: 'User', foreign_key: 'referrer_id'
  has_many :referrals, class_name: 'User', foreign_key: 'referrer_id'

  validates :email, presence: true, uniqueness: true, format: {
    with: /\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*/i,
    message: 'Invalid email format.'
  }
  validates :referral_code, uniqueness: true

  before_create :create_referral_code
  #after_create :send_welcome_email

  REFERRAL_STEPS = [
    {
      'count' => 5,
      'html' => 'Taco Dog Toy<br>w/ Squeaker',
      'class' => 'two',
      'image' =>  'refer/taco_toy_min.jpg'
    },
    {
      'count' => 10,
      'html' => 'Long-Lasting<br>Himalayan Dog Chew',
      'class' => 'three',
      'image' =>  'refer/himal_dog_treat_min.jpg'
    },
    {
      'count' => 25,
      'html' => 'Beef Jerky Treats<br>60 oz. Container',
      'class' => 'four',
      'image' =>  'refer/beef_jerky_treats_min.jpg'
    },
    {
      'count' => 50,
      'html' => 'Duck Jerky Treats<br>Premium 40 oz. Bag',
      'class' => 'five',
      'image' =>  'refer/duck_treats_min.jpg'
    }
  ]

  private

  def create_referral_code
    self.referral_code = UsersHelper.unused_referral_code
  end

  def send_welcome_email
    UserMailer.delay.signup_email(self)
  end
end
