require 'aws-sdk-s3'

class MasakiS3  
  def initialize
    credentials = Aws::Credentials.new(ENV['S3_ACCESS_KEY_ID'], ENV['S3_SECRET_ACCESS_KEY'])
    region = ENV['S3_REGION'] || 'us-west-2'
    Aws.config.update(
      region: region,
      credentials: credentials
    )
    @s3 = Aws::S3::Client.new
    @bucket = ENV['S3_BUCKET'] || 'hamana-masaki'
  end
  attr_reader :s3, :bucket

  def put_object(key, body)
    @s3.put_object(bucket: @bucket, key: key, body: body)
  end

  def get_object(key)
    @s3.get_object(bucket: @bucket, key: key)
  end

  def list_objects(prefix="")
    @s3.list_objects(bucket: @bucket, prefix: prefix)
  end

  def presigned(key)
    signer = Aws::S3::Presigner.new
    signer.presigned_url(
      :get_object, bucket: @bucket, key: key
    )
  end
end

if __FILE__ == $0
  require_relative 'masaki-pg'

  deck = MasakiPG::KVS.new('world')['deck']
  MasakiS3.new.put_object('deck', deck)
end