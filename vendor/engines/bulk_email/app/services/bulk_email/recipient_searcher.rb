module BulkEmail

  class RecipientSearcher

    include DateHelper
    include ActionView::Helpers::FormTagHelper

    attr_reader :search_fields

    DEFAULT_SORT = [:last_name, :first_name].freeze
    USER_TYPES = %i(customers authorized_users account_owners).freeze

    def initialize(search_fields)
      @search_fields = search_fields
    end

    def user_types
      @user_types ||= USER_TYPES & selected_user_types
    end

    def do_search
      user_types.collect do |user_type|
        public_send(:"search_#{user_type}")
      end.flatten.uniq
    end

    def has_search_fields?
      search_fields.present? && search_fields[:commit].present?
    end

    def search_params_as_hidden_fields
      [
        hidden_tags_for(:start_date, search_fields[:start_date]),
        hidden_tags_for(:end_date, search_fields[:end_date]),
        hidden_tags_for("bulk_email[user_types][]", search_fields[:bulk_email][:user_types]),
        hidden_tags_for("products[]", search_fields[:products]),
      ].flatten
    end

    def search_customers
      order_details = find_order_details.joins(order: :user)
      users.find_by_sql(order_details.select("distinct(users.id), users.*")
                                            .reorder("users.last_name, users.first_name")
                                            .merge(users)
                                            .to_sql)
    end

    def search_account_owners
      order_details = find_order_details_for_roles([AccountUser::ACCOUNT_OWNER])
      User.find_by_sql(order_details.joins(account: { account_users: :user })
                                     .select("distinct(users.id), users.*")
                                     .reorder("users.last_name, users.first_name")
                                     .merge(users)
                                     .to_sql)
    end

    def search_authorized_users
      result = users.joins(:product_users).uniq
      # if we don't have any products, listed get them all for the current facility
      product_ids = search_fields[:products].presence || Facility.find(search_fields[:facility_id]).products.map(&:id)
      result.where(product_users: { product_id: product_ids }).reorder(*self.class::DEFAULT_SORT)
    end

    private

    def hidden_tags_for(key, values)
      Array(values).map { |value| hidden_field_tag(key, value, id: nil) }
    end

    def selected_user_types
      return [] unless has_search_fields? && search_fields[:bulk_email].present?
      search_fields[:bulk_email][:user_types].map(&:to_sym)
    end

    def users
      User.active
    end

    def find_order_details
      OrderDetail
        .for_products(search_fields[:products])
        .joins(:order)
        .where(orders: { facility_id: search_fields[:facility_id] })
        .ordered_or_reserved_in_range(start_date, end_date)
    end

    def find_order_details_for_roles(roles)
      find_order_details.joins(account: :account_users).where(account_users: { user_role: roles })
    end

    def start_date
      parse_search_field_date(:start_date)
    end

    def end_date
      parse_search_field_date(:end_date)
    end

    def parse_search_field_date(date_field)
      return if search_fields[date_field].blank?
      parse_usa_date(search_fields[date_field].tr("-", "/"))
    end

  end

end
