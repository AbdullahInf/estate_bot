# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_04_23_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "brokers", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.string "google_uid", null: false
    t.string "google_access_token"
    t.string "google_refresh_token"
    t.datetime "google_token_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gmail_history_id"
    t.datetime "gmail_sync_started_at"
    t.datetime "gmail_watch_expiration"
    t.index ["email"], name: "index_brokers_on_email", unique: true
    t.index ["google_uid"], name: "index_brokers_on_google_uid", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.string "phone_number", null: false
    t.string "contact_name"
    t.jsonb "context", default: {}, null: false
    t.datetime "last_active_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number"], name: "index_conversations_on_phone_number", unique: true
  end

  create_table "email_attachments", force: :cascade do |t|
    t.bigint "inbound_email_id", null: false
    t.string "filename"
    t.string "content_type"
    t.integer "size"
    t.string "gmail_attachment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.binary "file_data"
    t.index ["inbound_email_id"], name: "index_email_attachments_on_inbound_email_id"
  end

  create_table "inbound_emails", force: :cascade do |t|
    t.bigint "broker_id", null: false
    t.string "gmail_message_id", null: false
    t.string "gmail_thread_id"
    t.string "sender_email"
    t.string "sender_name"
    t.string "subject"
    t.text "body_text"
    t.text "body_html"
    t.datetime "received_at"
    t.boolean "processed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["broker_id", "received_at"], name: "index_inbound_emails_on_broker_id_and_received_at"
    t.index ["broker_id"], name: "index_inbound_emails_on_broker_id"
    t.index ["gmail_message_id"], name: "index_inbound_emails_on_gmail_message_id", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content"
    t.string "message_type", default: "text", null: false
    t.string "whatsapp_message_id"
    t.string "media_id"
    t.jsonb "raw_payload", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["whatsapp_message_id"], name: "index_messages_on_whatsapp_message_id", unique: true, where: "(whatsapp_message_id IS NOT NULL)"
  end

  add_foreign_key "email_attachments", "inbound_emails"
  add_foreign_key "inbound_emails", "brokers"
  add_foreign_key "messages", "conversations"
end
