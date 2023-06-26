-- средний чек и прибыль по годам
select date_part('year', o.order_approved_at::date) "year",
	   avg(payment_value) mean_check,
	   sum(payment_value) total_income
from order_payments op 
join orders o on op.order_id = o.order_id 
where o.order_approved_at <> ''
group by "year"
order by 1 desc


-- количество клиентов, заказов и средний чек по городам
select c.customer_city,
	   count(distinct c.customer_unique_id) amount_of_customers,
	   count(distinct o.order_id) amount_of_orders,
	   avg(op.payment_value) mean_check
from customers c 
join orders o on c.customer_id = o.customer_id 
join order_payments op on op.order_id = o.order_id 
group by c.customer_city 
order by 4 desc


-- количество заказов и их общая сумма
select c.customer_unique_id ,
	   count(distinct o.order_id) number_of_orders,
	   sum(payment_value) total_payment
from customers c 
join orders o on c.customer_id = o.customer_id 
join order_payments op on o.order_id = op.order_id
group by c.customer_unique_id 
order by 3 desc


-- сравнение ожидаемого времени доставки и реального
select c.customer_state, 
	   floor(avg(order_delivered_customer_date::date - order_estimated_delivery_date::date))
from orders o
join customers c on o.customer_id = c.customer_id 
where order_status = 'delivered'
and order_delivered_customer_date <> ''
and order_estimated_delivery_date <> ''
group by customer_state 
order by 1 asc


-- наиболее распространенные товары
select pcnt.product_category_name_english,
	   count(*)
from order_items oi 
join products p on oi.product_id = p.product_id 
join product_category_name_translation pcnt on pcnt.product_category_name = p.product_category_name 
group by pcnt.product_category_name_english 
order by 2 desc

-- доля отмененных заказов по продовцам
with all_orders as (
	select seller_id,
		   count(distinct o.order_id) orders_count
	from (select order_id, order_status 
	  	from orders) o
	join (select order_id, seller_id
	 	 from order_items) oi
	on o.order_id = oi.order_id
	group by seller_id
),
canceled_orders as (
	select seller_id,
		   count(distinct o.order_id) canceled_orders_count
	from (select order_id, order_status 
	  	from orders) o
	join (select order_id, seller_id
	 	 from order_items) oi
	on o.order_id = oi.order_id
	where order_status = 'canceled'
	group by seller_id
	
)
select p.seller_id,
	   p.orders_count,
	   concat(p.canceled_orders_percent, '%') canceled_orders_percent
from (
	select ao.seller_id,
		   ao.orders_count,
		   round(((canceled_orders_count::float / orders_count) * 100)::numeric, 2) canceled_orders_percent
	from all_orders ao
	join canceled_orders co on ao.seller_id = co.seller_id
	order by 3 desc
) p

-- количество доставляемых заказов в города
select c.customer_city,
	   count(o.order_id) number_of_orders
from orders o 
join customers c on o.customer_id = c.customer_id 
where order_status = 'processing'
group by c.customer_city
order by 2 desc

-- средняя оценка категории товара
select pcnt.product_category_name_english product_category,
	   round(avg(or2.review_score)::numeric, 2) mean_score,
	   count(*) number_of_reviews
from order_reviews or2 
join order_items oi on oi.order_id = or2.order_id 
join products p on oi.product_id = p.product_id 
join product_category_name_translation pcnt on pcnt.product_category_name = p.product_category_name 
group by pcnt.product_category_name_english 
order by 2 desc

-- средняя оценка по продавцу
select oi.seller_id,
	   avg(or2.review_score) mean_score,
	   count(*) number_of_reviews
from order_reviews or2 
join order_items oi on or2.order_id = oi.order_id 
group by oi.seller_id 
order by 2 desc

-- средняя стоимость заказа по продавцам
select oi.seller_id,
	   round(avg(op.payment_value)::numeric, 2) mean_check
from order_items oi 
join order_payments op  on oi.order_id = op.order_id 
group by oi.seller_id 
order by 2 desc

-- извлечь год и месяц из даты заказа
select o.order_id,
	   date_part('year', o.order_purchase_timestamp::date) "year",
	   date_part('month', o.order_purchase_timestamp::date) "month",
	   date_part('day', o.order_purchase_timestamp::date) "day"
from orders o 

-- список клиентов, совершивших более 5 заказов
select customer_unique_id,
	   count(order_id) number_of_orders
from orders o 
join customers c on o.customer_id = c.customer_id 
group by customer_unique_id 
having count(order_id) > 5
order by 2 desc

-- предыдущий заказ
select order_id,
	   lag(order_id, 1, 'first order') over (partition by customer_unique_id order by o.order_approved_at desc) previous_order
from orders o
join customers c on o.customer_id = c.customer_id

-- средняя стоимость заказов пользователя
select o.order_id,
	   o.customer_id,
	   o.order_status,
	   op.payment_value,
	   avg(op.payment_value) over (partition by c.customer_unique_id) mean_orders
from orders o 
join order_payments op on o.order_id = op.order_id 
join customers c on o.customer_id = c.customer_id 

-- накопительная сумма продаж по дням
select distinct "date",
	   sum(op.payment_value) over (order by "date")
from (select order_id,
	         order_purchase_timestamp::date "date"
	  from orders) o 
join order_payments op on o.order_id = op.order_id 
order by 1

-- деление заказа по количеству товаров
select oi.order_id,
	   case 
	   		when order_item_id = 1 then 'одиночный заказ'
	   		when order_item_id < 5 then 'небольшой заказ'
	   		else 'большой заказ'
	   end order_type  
from order_items oi 

-- деление заказа по его стоимости
select o.*,
	   case
	   	when op.payment_value < 10 then 'маленький заказ'
	   	when op.payment_value < 50 then 'средний заказ'
	   	else 'большой заказ'
	   end cost_type
from orders o 
join order_payments op on o.order_id = op.order_id 
