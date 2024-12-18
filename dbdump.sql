--
-- PostgreSQL database dump
--

-- Dumped from database version 16.0
-- Dumped by pg_dump version 16.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fn_calculate_area(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_calculate_area(order_line_id integer, type character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    area_value NUMERIC;
BEGIN
    IF type = 'diamond' THEN
        SELECT SUM(sold.width * sold.height * sold.cnt)
        INTO area_value
        FROM public.sale_order_line sol
        JOIN public.sale_order_line_detail sold ON sol.id = sold.order_line_id
        WHERE sol.id = order_line_id AND sold.diamond = TRUE;

    ELSIF type = 'modeling' THEN
        SELECT SUM(sold.width * sold.height * sold.cnt)
        INTO area_value
        FROM public.sale_order_line sol
        JOIN public.sale_order_line_detail sold ON sol.id = sold.order_line_id
        WHERE sol.id = order_line_id AND sold.modeling = TRUE;

    ELSE
        RAISE EXCEPTION 'Invalid type value. Use "modeling" or "diamond".';
    END IF;

    RETURN COALESCE(area_value, 0);  -- Return 0 if no result found
END;
$$;


ALTER FUNCTION public.fn_calculate_area(order_line_id integer, type character varying) OWNER TO postgres;

--
-- Name: fn_calculate_perimeter(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_calculate_perimeter(order_line_id integer, type character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    perimeter_value NUMERIC;
BEGIN
    IF type = 'diamond' THEN
        SELECT SUM((sold.width * 2) + (sold.height * 2) * sold.cnt)
        INTO perimeter_value
        FROM public.sale_order_line sol
        JOIN public.sale_order_line_detail sold ON sol.id = sold.order_line_id
        WHERE sol.id = order_line_id AND sold.diamond = TRUE;

    ELSIF type = 'modeling' THEN
        SELECT SUM((sold.width * 2) + (sold.height * 2) * sold.cnt )
        INTO perimeter_value
        FROM public.sale_order_line sol
        JOIN public.sale_order_line_detail sold ON sol.id = sold.order_line_id
        WHERE sol.id = order_line_id AND sold.modeling = TRUE;

    ELSE
        RAISE EXCEPTION 'Invalid type value. Use "modeling" or "diamond".';
    END IF;

    RETURN COALESCE(perimeter_value, 0);  -- Return 0 if no result found
END;
$$;


ALTER FUNCTION public.fn_calculate_perimeter(order_line_id integer, type character varying) OWNER TO postgres;

--
-- Name: fn_product_custom_list(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_product_custom_list() RETURNS TABLE(main_assembly_id integer, subgroup_assembly_id integer, formatted_output character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
   WITH ProductTypes AS (
    SELECT 
        rpt.assembly_id,
        p.id AS product_id,
        p.name AS product_name,
        STRING_AGG(t.value, ', ') AS product_types
    FROM 
        public.product p
    JOIN 
        public.custom_product rpt ON p.id = rpt.product_id
    LEFT JOIN 
        public.product_type t ON t.id = ANY(rpt.product_type_id)
    GROUP BY 
        rpt.assembly_id, p.id, p.name
)
    SELECT
        p.assembly_id[1] AS main_assembly_id,
        p.assembly_id[2] AS subgroup_assembly_id,
        STRING_AGG(
            FORMAT('(%s, %s, %L, %L)', 
                p.assembly_id, 
                p.product_id, 
                p.product_name, 
                p.product_types
            ), 
            ' ' 
        )::character varying AS formatted_output
    FROM 
        ProductTypes p
    GROUP BY 
        p.assembly_id[1], p.assembly_id[2];

END;
$$;


ALTER FUNCTION public.fn_product_custom_list() OWNER TO postgres;

--
-- Name: fn_product_custom_list(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_product_custom_list(iproduct_id integer) RETURNS TABLE(main_assembly_id integer, subgroup_assembly_id integer, formatted_output character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
   WITH ProductTypes AS (
    SELECT 
        rpt.assembly_id,
        p.id AS product_id,
        p.name AS product_name,
        STRING_AGG(t.value, ', ') AS product_types
    FROM 
        public.product p
    JOIN 
        public.custom_product rpt ON p.id = rpt.product_id
    LEFT JOIN 
        public.product_type t ON t.id = ANY(rpt.product_type_id)
	   where p.id = coalesce(Iproduct_id,p.id)
    GROUP BY 
        rpt.assembly_id, p.id, p.name
)
    SELECT
        p.assembly_id[1] AS main_assembly_id,
        p.assembly_id[2] AS subgroup_assembly_id,
        STRING_AGG(
            FORMAT('(%s, %s, %L, %L)', 
                p.assembly_id, 
                p.product_id, 
                p.product_name, 
                p.product_types
            ), 
            ' ' 
        )::character varying AS formatted_output
    FROM 
        ProductTypes p
    GROUP BY 
        p.assembly_id[1], p.assembly_id[2];

END;
$$;


ALTER FUNCTION public.fn_product_custom_list(iproduct_id integer) OWNER TO postgres;

--
-- Name: fn_product_general(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_product_general() RETURNS TABLE(product_id integer, product_name character varying, type_values character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
SELECT 
p.id as product_id,
    p.name AS product_name,
    STRING_AGG(t.name || '( ' || t.id || ':' || t.value || ')',',')::character varying AS value
FROM 
    public.product p
left JOIN 
    public.product_type t ON p.id = ANY(t.related_product)
GROUP BY 
    p.id,p.name;
END;
$$;


ALTER FUNCTION public.fn_product_general() OWNER TO postgres;

--
-- Name: fn_product_list(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_product_list() RETURNS TABLE(product_id integer, product_name character varying, type_values character varying, file_data bytea)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        p.id AS product_id,
        p.name AS product_name,
        STRING_AGG(t.value, ', ')::character varying AS type_values 
		,f.file_data 
    FROM 
        public.custom_product rpt 
    JOIN 
         public.product p ON p.id = rpt.product_id
    left JOIN 
        public.product_type t ON  t.id = ANY(rpt.product_type_id )
	left join
		(select * from public.file where file_type = 'productimage')f on p.id = f.source_id

    GROUP BY 
        p.id, p.name,f.file_data;
END;
$$;


ALTER FUNCTION public.fn_product_list() OWNER TO postgres;

--
-- Name: fn_product_type_s(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_product_type_s() RETURNS TABLE(name character varying, type_values character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
SELECT 
    t.name,
    STRING_AGG(t.id || ': ' || t.value, ', ')::character varying AS type_values
FROM 
    public.product_type t
GROUP BY 
    t.name
ORDER BY 
    t.name;
	
END;
$$;


ALTER FUNCTION public.fn_product_type_s() OWNER TO postgres;

--
-- Name: fn_purchaseorder_s(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_purchaseorder_s() RETURNS TABLE(purchase_number character varying, partner_id integer, create_date timestamp without time zone, state_id integer, user_id integer, bill_id integer, note text, chat_id integer, amount_untaxed numeric, amount_tax numeric, amount_total numeric, currency_id integer, signed_by character varying, signed_date timestamp without time zone, print_template_id integer, update_date timestamp without time zone, order_line_id integer, id integer, parent_id integer, group_id integer, product_state_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        purchase_number, 
        partner_id, 
        create_date, 
        state_id, 
        user_id, 
        bill_id, 
        note, 
        chat_id, 
        amount_untaxed, 
        amount_tax, 
        amount_total, 
        currency_id, 
        signed_by, 
        signed_date, 
        print_template_id, 
        update_date, 
        order_line_id, 
        id, 
        parent_id, 
        group_id, 
        product_state_id
    FROM public.purchase_order;
END;
$$;


ALTER FUNCTION public.fn_purchaseorder_s() OWNER TO postgres;

--
-- Name: fn_saleorder_grid_s(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_saleorder_grid_s() RETURNS TABLE(id integer, order_number character varying, partner_id integer, create_date timestamp without time zone, title character varying, project_name character varying, note text, amount_total numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT s.id, s.order_number, s.partner_id, s.create_date, st.title, s.project_name, s.note, s.amount_total
    FROM sale_order s 
    LEFT JOIN state st ON s.state_id = st.id;
END;
$$;


ALTER FUNCTION public.fn_saleorder_grid_s() OWNER TO postgres;

--
-- Name: fn_saleorder_line_detail_s(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_saleorder_line_detail_s(p_order_line_id integer) RETURNS TABLE(order_number character varying, partner_id integer, create_date timestamp without time zone, project_name character varying, note text, amount_total numeric, line_product_description character varying, line_price_unit numeric, line_qty numeric, width numeric, height numeric, cnt integer, code character, fitter boolean, modeling boolean, diamond boolean, master boolean, id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        s.order_number,
        s.partner_id,
        s.create_date,
        s.project_name,
        s.note,
        s.amount_total,
		public.fn_product_custom_list(sol.product_id),
        sol.product_description AS line_product_description,
        sol.price_unit AS line_price_unit,
        sol.qty AS line_qty,
        sold.width,
        sold.height,
        sold.cnt,
        sold.code,
        sold.fitter,
        sold.modeling,
        sold.diamond,
        sold.master,
		sold.id 
    FROM 
        public.sale_order_line sol
    JOIN 
        public.sale_order s ON sol.sale_order_id = s.id
    LEFT JOIN 
        public.sale_order_line_detail sold ON sol.id = sold.order_line_id
    WHERE 
        sol.id = p_order_line_id;
END;
$$;


ALTER FUNCTION public.fn_saleorder_line_detail_s(p_order_line_id integer) OWNER TO postgres;

--
-- Name: fn_saleorder_line_s(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_saleorder_line_s(p_line_id integer) RETURNS TABLE(order_number character varying, partner_id integer, create_date timestamp without time zone, project_name character varying, note text, amount_total numeric, line_product_description character, line_price_unit numeric, line_qty numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        s.order_number, 
        s.partner_id, 
        s.create_date, 
        s.project_name, 
        s.note, 
        s.amount_total,
        sol.product_description AS line_product_description,
        sol.price_unit AS line_price_unit,
        sol.qty AS line_qty
    FROM 
        public.sale_order s
    LEFT JOIN 
        public.sale_order_line sol ON s.id = sol.sale_order_id
    WHERE 
        sol.id = p_line_id;
END;
$$;


ALTER FUNCTION public.fn_saleorder_line_s(p_line_id integer) OWNER TO postgres;

--
-- Name: fn_saleorder_s(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_saleorder_s(order_id integer) RETURNS TABLE(id integer, order_number character varying, partner_id integer, create_date timestamp without time zone, title character varying, project_name character varying, note text, amount_total numeric, product_description character varying, line_number integer, price_unit numeric, product_id integer, qty numeric, uom_id integer, qty_delivered numeric, qty_to_invoice numeric, diamond_length numeric, modeling_count integer, modeling_size numeric, master_size numeric, min_size integer, detail_uom_id integer, order_line_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        s.id, 
        s.order_number, 
        s.partner_id, 
        s.create_date, 
        st.title, 
        s.project_name, 
        s.note, 
        s.amount_total,
        sol.product_description,
        sol.line_number, 
        sol.price_unit,
        sol.product_id, 
        sol.qty,
        sol.uom_id, 
        sol.qty_delivered, 
        sol.qty_to_invoice,
        sol.diamond_length, 
        sol.modeling_count,
        sol.modeling_size,
        sol.master_size,
        sol.min_size,
        sol.detail_uom_id, 
        sol.id AS order_line_id
    FROM sale_order s 
    LEFT JOIN sale_order_line sol ON s.id = sol.sale_order_id
    LEFT JOIN state st ON s.state_id = st.id
    WHERE s.id = order_id;
END;
$$;


ALTER FUNCTION public.fn_saleorder_s(order_id integer) OWNER TO postgres;

--
-- Name: sp_address_i(integer, text, text, text, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_address_i(IN partner_id integer, IN address text, IN title text, IN location text, IN isdefault boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert into the Address table
    INSERT INTO public."Address" (
        partner_id, address, title, location, isdefault
    )
    VALUES (
        partner_id, address, title, location, isdefault
    );
    


END;
$$;


ALTER PROCEDURE public.sp_address_i(IN partner_id integer, IN address text, IN title text, IN location text, IN isdefault boolean) OWNER TO postgres;

--
-- Name: sp_address_s(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_address_s(IN partner_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Select statement to retrieve address details for the given partner_id
    RAISE NOTICE 'Retrieving addresses for Partner ID: %', partner_id;


    SELECT *
    FROM public."Address"
    WHERE partner_id = partner_id;

END;
$$;


ALTER PROCEDURE public.sp_address_s(IN partner_id integer) OWNER TO postgres;

--
-- Name: sp_product_custom_i(integer, integer[], integer[]); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_product_custom_i(IN p_id integer, IN p_product_type_ids integer[], IN assembly_id integer[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO public.custom_product (product_id, product_type_id,assembly_id)
    VALUES (p_id, p_product_type_ids,assembly_id);
END;
$$;


ALTER PROCEDURE public.sp_product_custom_i(IN p_id integer, IN p_product_type_ids integer[], IN assembly_id integer[]) OWNER TO postgres;

--
-- Name: sp_product_general_i(character varying, integer, character varying, bytea); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_product_general_i(IN name character varying, IN user_id integer, IN image_name character varying, IN image_file bytea)
    LANGUAGE plpgsql
    AS $$
DECLARE
    image_id INT;     -- Variable to hold the ID of the inserted image
    product_id INT;   -- Variable to hold the ID of the inserted product
BEGIN
    -- Insert the image into the attachment table and capture the generated image ID
    INSERT INTO public.attachment(name, path)
    VALUES (image_name, image_file)
    RETURNING id INTO image_id;

    -- Insert the product into the product table and capture the generated product ID
    INSERT INTO public.product(
        active, barcode, user_id, create_date, image_id, "saleORpurchase", name
    )
    VALUES (TRUE, NULL, user_id, NOW(), image_id, 1, name)
    RETURNING id INTO product_id;  -- Capture the generated product ID



    RAISE NOTICE 'Product with ID % has been successfully created.', product_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'An error occurred while inserting product: %', SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_product_general_i(IN name character varying, IN user_id integer, IN image_name character varying, IN image_file bytea) OWNER TO postgres;

--
-- Name: sp_product_related_u(integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_product_related_u(IN p_product_type_id integer, IN p_product_id integer, IN p_action character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_action = 'add' THEN
        UPDATE public.product_type
        SET related_product = array_append(related_product, p_product_id)
        WHERE id = p_product_type_id;

        RAISE NOTICE 'Product ID % added to product type ID %', p_product_id, p_product_type_id;

    ELSIF p_action = 'remove' THEN
        UPDATE public.product_type
        SET related_product = array_remove(related_product, p_product_id)
        WHERE id = p_product_type_id;

        RAISE NOTICE 'Product ID % removed from product type ID %', p_product_id, p_product_type_id;

    ELSE
        RAISE EXCEPTION 'Invalid action: %', p_action;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_product_related_u(IN p_product_type_id integer, IN p_product_id integer, IN p_action character varying) OWNER TO postgres;

--
-- Name: sp_product_type_i(character varying, character varying, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_product_type_i(IN p_name character varying, IN p_value character varying, IN p_ename character varying, IN p_evalue character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert the new product type into the product_type table
    INSERT INTO public.product_type (name, value, ename, evalue)
    VALUES (p_name, p_value, p_ename, p_evalue);

    -- Optionally, you can raise a notice to confirm insertion
    RAISE NOTICE 'Inserted product type: %', p_name;

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Product type with name "%" already exists.', p_name;
    WHEN others THEN
        RAISE EXCEPTION 'An error occurred: %', SQLERRM;
END;
$$;


ALTER PROCEDURE public.sp_product_type_i(IN p_name character varying, IN p_value character varying, IN p_ename character varying, IN p_evalue character varying) OWNER TO postgres;

--
-- Name: sp_purchaseorder_from_purchaseorder_i(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_from_purchaseorder_i(IN sale_order_line_id integer, IN user_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    number_of_orders INT;
    new_purchase_number VARCHAR;
    purchase_order_id INT;  -- Variable to hold the newly created purchase order ID
BEGIN
    -- Count existing purchase orders for the given sale order line
    SELECT COUNT(*)
    INTO number_of_orders
    FROM public.purchase_order sol 
    WHERE order_line_id = sale_order_line_id;

    -- Generate a new purchase number based on existing data
    SELECT CAST(so.order_number AS VARCHAR) || CAST(sol.id AS VARCHAR) || CAST(number_of_orders AS VARCHAR)
    INTO new_purchase_number
    FROM public.sale_order so  
    JOIN public.sale_order_line sol ON so.id = sol.sale_order_id
    WHERE sol.id = sale_order_line_id;

    -- Insert the new purchase order into the database and capture the generated ID
    INSERT INTO public.purchase_order (
        order_line_id,
        purchase_number,
        partner_id,
        create_date,
        state_id,
        user_id,
        bill_id,
        note,
        chat_id,
        amount_untaxed,
        amount_tax,
        amount_total,
        currency_id,
        signed_by,
        signed_date,
        print_template_id,
        update_date,
        parent_id,
        group_id,
        product_state_id
    )
    VALUES (
        sale_order_line_id, 
        new_purchase_number,  -- Use the generated purchase number here
        (SELECT so.partner_id FROM public.sale_order so JOIN public.sale_order_line sol ON so.id = sol.sale_order_id WHERE sol.id = sale_order_line_id),
        NOW(),  -- Use current timestamp for creation date
        0,  -- Assuming '0' is a default state ID; adjust as necessary
        user_id, 
        NULL,  -- Assuming bill ID is not provided; adjust if needed
        (SELECT so.note FROM public.sale_order so JOIN public.sale_order_line sol ON so.id = sol.sale_order_id WHERE sol.id = sale_order_line_id),
        (SELECT so.chat_id FROM public.sale_order so JOIN public.sale_order_line sol ON so.id = sol.sale_order_id WHERE sol.id = sale_order_line_id),
        NULL,  -- Assuming amounts are not specified; adjust if needed
        NULL,  
        NULL,  
        (SELECT currency_id FROM public.sale_order WHERE id = (SELECT so.id FROM public.sale_order so JOIN public.sale_order_line sol ON so.id = sol.sale_order_id WHERE sol.id = sale_order_line_id)),  -- Get currency from sale order
        NULL,  
        NULL,  
        NOW(),  -- Use current timestamp for update date
        NULL,  
        NULL,  
        NULL   -- Assuming product state ID is not provided; adjust if needed
    )
    RETURNING id INTO purchase_order_id;  -- Capture the ID of the newly inserted purchase order

    -- Insert related details into the purchase order line detail table
    INSERT INTO public.purchase_order_line_detail (
        purchase_line_id, 
        width, 
        height, 
        cnt, 
        code, 
        fitter_type, 
        moddeling, 
        diamond, 
        master
    )
    SELECT 
        purchase_order_id,  -- Use the captured purchase order ID here
        width, 
        height, 
        cnt, 
        code, 
        fitter_type, 
        moddeling, 
        diamond, 
        master 
    FROM public.sale_order_line_detail
    WHERE order_line_id = sale_order_line_id;

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_from_purchaseorder_i(IN sale_order_line_id integer, IN user_id integer) OWNER TO postgres;

--
-- Name: sp_purchaseorder_from_saleorder_i(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_from_saleorder_i(IN sale_order_line_id integer, IN user_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    number_of_orders INT;
    new_purchase_number VARCHAR;
BEGIN
    -- Count existing purchase orders for the given sale order line
    SELECT COUNT(*)
    INTO number_of_orders
    FROM public.purchase_order sol 
    WHERE order_line_id = sale_order_line_id;

    -- Generate a new purchase number based on existing data
    SELECT CAST(so.order_number AS VARCHAR) || CAST(sol.id AS VARCHAR) || CAST(number_of_orders AS VARCHAR)
    INTO new_purchase_number
    FROM public.sale_order so  
    JOIN public.sale_order_line sol ON so.id = sol.sale_order_id
    WHERE sol.id = sale_order_line_id;

    -- Insert the new purchase order into the database
    INSERT INTO public.purchase_order (
        order_line_id,
        purchase_number,
        partner_id,
        create_date,
        state_id,
        user_id,
        bill_id,
        note,
        chat_id,
        amount_untaxed,
        amount_tax,
        amount_total,
        currency_id,
        signed_by,
        signed_date,
        print_template_id,
        update_date,
        parent_id,
        group_id,
        product_state_id
    )
    SELECT 
        sale_order_line_id, 
        new_purchase_number, 
        so.partner_id, 
        NOW(),  -- Use current timestamp for creation date
        0,  -- Assuming '0' is a default state ID; adjust as necessary
        user_id, 
        NULL,  -- Assuming bill ID is not provided; adjust if needed
        so.note, 
        so.chat_id,
        NULL,  -- Assuming amounts are not specified; adjust if needed
        NULL,  
        NULL,  
        (SELECT currency_id FROM public.sale_order WHERE id = so.id),  -- Get currency from sale order
        NULL,  
        NULL,  
        NOW(),  -- Use current timestamp for update date
        NULL,  
        NULL,  
        NULL   -- Assuming product state ID is not provided; adjust if needed
    FROM public.sale_order so  
    JOIN public.sale_order_line sol ON so.id = sol.sale_order_id
    WHERE sol.id = sale_order_line_id;

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_from_saleorder_i(IN sale_order_line_id integer, IN user_id integer) OWNER TO postgres;

--
-- Name: sp_purchaseorder_line_detail_u(integer, character varying, integer, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, integer, numeric, integer, numeric, numeric, numeric, character varying, timestamp without time zone, integer, boolean, character varying, character varying, character varying, character varying, integer, integer, integer, integer, numeric, numeric, integer, character varying, character varying, character varying, boolean, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_line_detail_u(IN p_id integer, IN p_product_description character varying, IN p_line_number integer, IN p_price_unit numeric, IN p_price_subtotal numeric, IN p_price_tax numeric, IN p_price_total numeric, IN p_price_reduce numeric, IN p_price_reduce_taxinc numeric, IN p_price_reduce_taxexcl numeric, IN p_discount numeric, IN p_product_id integer, IN p_qty numeric, IN p_uom_id integer, IN p_qty_delivered numeric, IN p_qty_to_invoice numeric, IN p_customer_lead numeric, IN p_display_type character varying, IN p_update_date timestamp without time zone, IN p_order_line_detail_id integer, IN p_diamond boolean, IN p_modeling character varying, IN p_modeling_size character varying, IN p_master_size character varying, IN p_min_size character varying, IN p_detail_uom_id integer, IN p_producing_state_id integer, IN p_producing_group_id integer, IN s_order_line_id integer, IN s_width numeric, IN s_height numeric, IN s_cnt integer, IN s_code character varying, IN s_fitter_type character varying, IN s_modelling character varying, IN s_diamond boolean, IN s_master character varying, IN s_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the purchase_order_line table with the provided values
    UPDATE public.purchase_order_line
    SET 
        product_description = p_product_description,
        line_number = p_line_number,
        price_unit = p_price_unit,
        price_subtotal = p_price_subtotal,
        price_tax = p_price_tax,
        price_total = p_price_total,
        price_reduce = p_price_reduce,
        price_reduce_taxinc = p_price_reduce_taxinc,
        price_reduce_taxexcl = p_price_reduce_taxexcl,
        discount = p_discount,
        product_id = p_product_id,
        qty = p_qty,
        uom_id = p_uom_id,
        qty_delivered = p_qty_delivered,
        qty_to_invoice = p_qty_to_invoice,
        customer_lead = p_customer_lead,
        display_type = p_display_type,
        update_date = COALESCE(p_update_date, NOW()),  -- Use current timestamp if null
        order_line_detail_id = p_order_line_detail_id,
        diamond = p_diamond, 
        modeling = p_modeling, 
        modeling_size = p_modeling_size, 
        master_size = p_master_size, 
        min_size = p_min_size, 
        detail_uom_id = p_detail_uom_id, 
        producing_state_id = p_producing_state_id, 
        producing_group_id = p_producing_group_id
    WHERE id = p_id;  -- Update where the ID matches the provided ID

    -- Update the sale_order_line_detail table with the provided values
    UPDATE public.sale_order_line_detail
    SET 
        order_line_id = s_order_line_id,
        width = s_width,
        height = s_height,
        cnt = s_cnt,
        code = s_code,
        fitter_type = s_fitter_type,
        moddeling = s_modelling,  -- Ensure spelling matches your schema (modelling vs. moddeling)
        diamond = s_diamond, 
        master = s_master 
    WHERE id = s_id;  -- Update where the ID matches the provided ID for sale_order_line_detail

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_line_detail_u(IN p_id integer, IN p_product_description character varying, IN p_line_number integer, IN p_price_unit numeric, IN p_price_subtotal numeric, IN p_price_tax numeric, IN p_price_total numeric, IN p_price_reduce numeric, IN p_price_reduce_taxinc numeric, IN p_price_reduce_taxexcl numeric, IN p_discount numeric, IN p_product_id integer, IN p_qty numeric, IN p_uom_id integer, IN p_qty_delivered numeric, IN p_qty_to_invoice numeric, IN p_customer_lead numeric, IN p_display_type character varying, IN p_update_date timestamp without time zone, IN p_order_line_detail_id integer, IN p_diamond boolean, IN p_modeling character varying, IN p_modeling_size character varying, IN p_master_size character varying, IN p_min_size character varying, IN p_detail_uom_id integer, IN p_producing_state_id integer, IN p_producing_group_id integer, IN s_order_line_id integer, IN s_width numeric, IN s_height numeric, IN s_cnt integer, IN s_code character varying, IN s_fitter_type character varying, IN s_modelling character varying, IN s_diamond boolean, IN s_master character varying, IN s_id integer) OWNER TO postgres;

--
-- Name: sp_purchaseorder_line_details_s(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_line_details_s()
    LANGUAGE plpgsql
    AS $$
BEGIN


    CREATE TEMP TABLE temp_purchase_order_line_details AS
    SELECT
       id,
       purchase_line_id,
       width,
       height,
       cnt,
       code,
       fitter_type,
       moddeling,
       diamond,
       master
    FROM public.purchase_order_line_detail;

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_line_details_s() OWNER TO postgres;

--
-- Name: sp_purchaseorder_line_s(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_line_s()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE temp_purchase_order_lines AS
    SELECT 
        id, 
        product_description, 
        line_number, 
        price_unit, 
        price_subtotal, 
        price_tax, 
        price_total, 
        price_reduce, 
        price_reduce_taxinc, 
        price_reduce_taxexcl, 
        discount, 
        product_id, 
        qty, 
        uom_id, 
        qty_delivered, 
        qty_to_invoice, 
        purchase_id, 
        customer_lead, 
        display_type, 
        create_uid, 
        create_date, 
        update_date, 
        order_line_detail_id,
        diamond,
        modeling,
        modeling_size,
        master_size,
        min_size,
        detail_uom_id,
        producing_state_id,
        producing_group_id
    FROM public.purchase_order_line;

 

  
END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_line_s() OWNER TO postgres;

--
-- Name: sp_purchaseorder_line_u(integer, character varying, integer, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, integer, numeric, integer, numeric, numeric, numeric, character varying, timestamp without time zone, integer, boolean, character varying, character varying, character varying, character varying, integer, integer, integer, integer, numeric, numeric, integer, character varying, character varying, character varying, boolean, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_line_u(IN p_id integer, IN p_product_description character varying, IN p_line_number integer, IN p_price_unit numeric, IN p_price_subtotal numeric, IN p_price_tax numeric, IN p_price_total numeric, IN p_price_reduce numeric, IN p_price_reduce_taxinc numeric, IN p_price_reduce_taxexcl numeric, IN p_discount numeric, IN p_product_id integer, IN p_qty numeric, IN p_uom_id integer, IN p_qty_delivered numeric, IN p_qty_to_invoice numeric, IN p_customer_lead numeric, IN p_display_type character varying, IN p_update_date timestamp without time zone, IN p_order_line_detail_id integer, IN p_diamond boolean, IN p_modeling character varying, IN p_modeling_size character varying, IN p_master_size character varying, IN p_min_size character varying, IN p_detail_uom_id integer, IN p_producing_state_id integer, IN p_producing_group_id integer, IN s_order_line_id integer, IN s_width numeric, IN s_height numeric, IN s_cnt integer, IN s_code character varying, IN s_fitter_type character varying, IN s_modelling character varying, IN s_diamond boolean, IN s_master character varying, IN s_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the purchase_order_line table with the provided values
    UPDATE public.purchase_order_line
    SET 
        product_description = p_product_description,
        line_number = p_line_number,
        price_unit = p_price_unit,
        price_subtotal = p_price_subtotal,
        price_tax = p_price_tax,
        price_total = p_price_total,
        price_reduce = p_price_reduce,
        price_reduce_taxinc = p_price_reduce_taxinc,
        price_reduce_taxexcl = p_price_reduce_taxexcl,
        discount = p_discount,
        product_id = p_product_id,
        qty = p_qty,
        uom_id = p_uom_id,
        qty_delivered = p_qty_delivered,
        qty_to_invoice = p_qty_to_invoice,
        customer_lead = p_customer_lead,
        display_type = p_display_type,
        update_date = COALESCE(p_update_date, NOW()),  -- Use current timestamp if null
        order_line_detail_id = p_order_line_detail_id,
        diamond = p_diamond, 
        modeling = p_modeling, 
        modeling_size = p_modeling_size, 
        master_size = p_master_size, 
        min_size = p_min_size, 
        detail_uom_id = p_detail_uom_id, 
        producing_state_id = p_producing_state_id, 
        producing_group_id = p_producing_group_id
    WHERE id = p_id;  -- Update where the ID matches the provided ID

    -- Update the sale_order_line_detail table with the provided values
    UPDATE public.sale_order_line_detail
    SET 
        order_line_id = s_order_line_id,
        width = s_width,
        height = s_height,
        cnt = s_cnt,
        code = s_code,
        fitter_type = s_fitter_type,
        moddeling = s_modelling,
        diamond = s_diamond, 
        master = s_master 
    WHERE purchase_line_id = p_id;  -- Update where the ID matches the provided ID for sale_order_line_detail

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_line_u(IN p_id integer, IN p_product_description character varying, IN p_line_number integer, IN p_price_unit numeric, IN p_price_subtotal numeric, IN p_price_tax numeric, IN p_price_total numeric, IN p_price_reduce numeric, IN p_price_reduce_taxinc numeric, IN p_price_reduce_taxexcl numeric, IN p_discount numeric, IN p_product_id integer, IN p_qty numeric, IN p_uom_id integer, IN p_qty_delivered numeric, IN p_qty_to_invoice numeric, IN p_customer_lead numeric, IN p_display_type character varying, IN p_update_date timestamp without time zone, IN p_order_line_detail_id integer, IN p_diamond boolean, IN p_modeling character varying, IN p_modeling_size character varying, IN p_master_size character varying, IN p_min_size character varying, IN p_detail_uom_id integer, IN p_producing_state_id integer, IN p_producing_group_id integer, IN s_order_line_id integer, IN s_width numeric, IN s_height numeric, IN s_cnt integer, IN s_code character varying, IN s_fitter_type character varying, IN s_modelling character varying, IN s_diamond boolean, IN s_master character varying, IN s_id integer) OWNER TO postgres;

--
-- Name: sp_purchaseorder_s(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_s()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Create a temporary table for purchase orders
    CREATE TEMP TABLE temp_purchase_orders AS
    SELECT 
        purchase_number, 
        partner_id, 
        create_date, 
        state_id, 
        user_id, 
        bill_id, 
        note, 
        chat_id, 
        amount_untaxed, 
        amount_tax, 
        amount_total, 
        currency_id, 
        signed_by, 
        signed_date, 
        print_template_id, 
        update_date, 
        order_line_id, 
        id, 
        parent_id, 
        group_id, 
        product_state_id
    FROM public.purchase_order;

  
END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_s() OWNER TO postgres;

--
-- Name: sp_purchaseorder_state_sign_u(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_state_sign_u(IN purchase_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- Check if the vendor group is 'VIP'
    IF EXISTS (
        SELECT 1 
        FROM public.purchase_order po
        JOIN public.partner p ON po.partner_id = p.id
        JOIN public.partner_group pg ON p.vendor_group_id = pg.id
        WHERE pg.type = 'vendor_payment' AND p.name = 'VIP'
          AND po.id = purchase_id  -- Ensure we are checking the correct purchase order
    ) THEN
        UPDATE public.purchase_order
        SET state = 7
        WHERE id = purchase_id;  -- Use 'id' to refer to the primary key of the purchase_order table

    -- Check if the vendor group is 'normal'
    ELSIF EXISTS (
        SELECT 1 
        FROM public.purchase_order po
        JOIN public.partner p ON po.partner_id = p.id
        JOIN public.partner_group pg ON p.vendor_group_id = pg.id
        WHERE pg.type = 'vendor_payment' AND p.name = 'normal'
          AND po.id = purchase_id  -- Ensure we are checking the correct purchase order
    ) THEN
        UPDATE public.purchase_order
        SET state = 21
        WHERE id = purchase_id;  -- Use 'id' to refer to the primary key of the purchase_order table

    END IF;

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_state_sign_u(IN purchase_id integer) OWNER TO postgres;

--
-- Name: sp_purchaseorder_u(integer, character varying, integer, integer, text, numeric, numeric, numeric, integer, timestamp without time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_u(IN purchase_id integer, IN purchase_number character varying, IN partner_id integer, IN user_id integer, IN note text, IN amount_untaxed numeric, IN amount_tax numeric, IN amount_total numeric, IN currency_id integer, IN update_date timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN

-- Update the purchase order details
UPDATE public.purchase_order
SET 
    purchase_number = purchase_number, 
    partner_id = partner_id, 
    user_id = user_id, 
    bill_id = bill_id, 
    note = note, 
    amount_untaxed = amount_untaxed, 
    amount_tax = amount_tax, 
    amount_total = amount_total, 
    currency_id = currency_id, 
    update_date = update_date
WHERE id = purchase_id;  -- Condition to identify the record to update

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_u(IN purchase_id integer, IN purchase_number character varying, IN partner_id integer, IN user_id integer, IN note text, IN amount_untaxed numeric, IN amount_tax numeric, IN amount_total numeric, IN currency_id integer, IN update_date timestamp without time zone) OWNER TO postgres;

--
-- Name: sp_purchaseorder_vendor_factor_i(integer, integer, bytea); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_vendor_factor_i(IN partner_id integer, IN purchase_id integer, IN factor_file bytea)
    LANGUAGE plpgsql
    AS $$
BEGIN


    UPDATE public.purchase_vendor
    SET factor_file = factor_file  
    WHERE purchase_id = purchase_id AND partner_id = partner_id;  

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_vendor_factor_i(IN partner_id integer, IN purchase_id integer, IN factor_file bytea) OWNER TO postgres;

--
-- Name: sp_purchaseorder_vendor_selecting_u(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_vendor_selecting_u(IN partner_id integer, IN purchase_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- Update the is_selected field in the purchase_vendor table
    UPDATE public.purchase_vendor
    SET is_selected = 1  
    WHERE purchase_id = purchase_id AND partner_id = partner_id;  
	
	update purchase_order
	set state  = 19 
	where purchase_id = purchase_id;

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_vendor_selecting_u(IN partner_id integer, IN purchase_id integer) OWNER TO postgres;

--
-- Name: sp_purchaseorder_vendor_u(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_purchaseorder_vendor_u(IN partner_id integer, IN purchase_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN


    INSERT INTO public.purchase_vendor (purchase_id, vendor_id)  
    VALUES (purchase_id, partner_id);  
	
	update purchase_order
	set state= 18
	where id = purchase_id;

END;
$$;


ALTER PROCEDURE public.sp_purchaseorder_vendor_u(IN partner_id integer, IN purchase_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_i(character varying, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_i(IN order_number character varying, IN partner_id integer, IN project_name character varying, OUT inserted_order_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE 
    create_date TIMESTAMP;
    state_id INT;
    update_uid INT;
    shipping_id INT;
    note VARCHAR(2000);
    chat_id INT;
    amount_untaxed DECIMAL(10, 2);
    amount_tax DECIMAL(10, 2);
    amount_total DECIMAL(10, 2);
    currency_id INT;
    signed_by_id INT;
    signed_date TIMESTAMP;
    access_token VARCHAR(100);
    print_template_id INT;
    update_date TIMESTAMP;
BEGIN
    -- Initialize variables
    create_date := NOW();
    state_id := 0;
    update_uid := NULL;
    shipping_id := NULL; -- This will be set later
    note := NULL;
    chat_id := NULL;
    amount_untaxed := NULL;
    amount_tax := NULL;
    amount_total := NULL;
    currency_id := 1;  -- Assuming a default currency ID
    signed_by_id := NULL;
    signed_date := NULL;
    access_token := NULL;
    print_template_id := NULL;
    update_date := NULL;

    -- Retrieve the shipping ID based on partner ID
    SELECT ad.id 
    INTO shipping_id
    FROM partner p
    JOIN address ad ON p.id = ad.partner_id 
    WHERE p.id = ad.partner_id AND ad.isdefault = TRUE;

    -- Insert into the sale_order table and return the inserted order ID
    INSERT INTO public.sale_order (
        order_number, 
        partner_id, 
        create_date, 
        state_id, 
        update_uid,
        shipping_id, 
        project_name, 
        note, 
        chat_id, 
        amount_untaxed, 
        amount_tax, 
        amount_total, 
        currency_id, 
        signed_by_id, 
        signed_date, 
        access_token, 
        print_template_id, 
        update_date
    )
    VALUES (
        order_number, 
        partner_id, 
        create_date, 
        state_id, 
        update_uid, 
        shipping_id, 
        project_name, 
        note, 
        chat_id, 
        amount_untaxed, 
        amount_tax, 
        amount_total, 
        currency_id, 
        signed_by_id, 
        signed_date, 
        access_token, 
        print_template_id, 
        update_date
    )
    RETURNING id INTO inserted_order_id;  -- Capture the inserted order ID

END;
$$;


ALTER PROCEDURE public.sp_saleorder_i(IN order_number character varying, IN partner_id integer, IN project_name character varying, OUT inserted_order_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_line_d(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_line_d(IN iline_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Delete the sale_order_line record with the given line ID
    DELETE FROM public.sale_order_line
    WHERE id = iline_id;

    -- Optional: Raise a notice if no record was found
    IF NOT FOUND THEN
        RAISE NOTICE 'No record found with line ID: %', iline_id;
    ELSE
        RAISE NOTICE 'Record with line ID: % has been deleted.', iline_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_line_d(IN iline_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_line_detail_d(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_line_detail_d(IN pid integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Delete the sale_order_line_detail record with the given ID
    DELETE FROM public.sale_order_line_detail
    WHERE id = pid;

    -- Optional: Raise a notice if no record was found
    IF NOT FOUND THEN
        RAISE NOTICE 'No record found with order line detail ID: %', pid;
    ELSE
        RAISE NOTICE 'Record with order line detail ID: % has been deleted.', pid;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_line_detail_d(IN pid integer) OWNER TO postgres;

--
-- Name: sp_saleorder_line_detail_i(integer, numeric, numeric, integer, character varying, boolean, boolean, boolean, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_line_detail_i(IN order_line_id integer, IN width numeric, IN height numeric, IN cnt integer, IN code character varying, IN fitter boolean DEFAULT false, IN modeling boolean DEFAULT false, IN diamond boolean DEFAULT false, IN master boolean DEFAULT false)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert into the sale_order_line_detail table
    INSERT INTO public.sale_order_line_detail (
        order_line_id, width, height, cnt, code,
        fitter, modeling, diamond, master
    )
    VALUES (
        order_line_id, width, height, cnt, code,
        fitter, modeling, diamond, master
    );
END;
$$;


ALTER PROCEDURE public.sp_saleorder_line_detail_i(IN order_line_id integer, IN width numeric, IN height numeric, IN cnt integer, IN code character varying, IN fitter boolean, IN modeling boolean, IN diamond boolean, IN master boolean) OWNER TO postgres;

--
-- Name: sp_saleorder_line_detail_u(integer, numeric, numeric, integer, character varying, boolean, boolean, boolean, boolean); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_line_detail_u(IN pid integer, IN pwidth numeric, IN pheight numeric, IN pcnt integer, IN pcode character varying, IN pfitter boolean, IN pmodeling boolean, IN pdiamond boolean, IN pmaster boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the sale_order_line_detail table
    UPDATE public.sale_order_line_detail
    SET 
        width = COALESCE(pwidth, width),               -- Update width if not NULL
        height = COALESCE(pheight, height),             -- Update height if not NULL
        cnt = COALESCE(pcnt, cnt),                       -- Update count if not NULL
        code = COALESCE(pcode, code),                   -- Update code if not NULL
        fitter = COALESCE(pfitter, fitter), -- Update fitter type if not NULL
        modeling = COALESCE(pmodeling, modeling),       -- Update modeling if not NULL
        diamond = COALESCE(pdiamond, diamond),           -- Update diamond if not NULL
        master = COALESCE(pmaster, master)               -- Update master if not NULL
    WHERE id = pid;              -- Identify the record to update

    IF NOT FOUND THEN
        RAISE NOTICE 'No record found with order line ID: %', pid;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_line_detail_u(IN pid integer, IN pwidth numeric, IN pheight numeric, IN pcnt integer, IN pcode character varying, IN pfitter boolean, IN pmodeling boolean, IN pdiamond boolean, IN pmaster boolean) OWNER TO postgres;

--
-- Name: sp_saleorder_line_i(integer, character varying, integer, character varying, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_line_i(IN order_id integer, IN product_description character varying, IN product_id integer, IN project_name character varying, IN detail_uom_id integer, OUT order_line_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE 
    line_number INT; 
    price_unit DECIMAL(10,2); 
    new_line_id INT; -- Variable to hold the new line ID
    price_subtotal DECIMAL(10,2) DEFAULT 0; 
    price_tax DECIMAL(10,2) DEFAULT 0; 
    price_total DECIMAL(10,2) DEFAULT 0; 
    price_reduce DECIMAL(10,2) DEFAULT 0; 
    price_reduce_taxinc DECIMAL(10,2) DEFAULT 0; 
    price_reduce_taxexcl DECIMAL(10,2) DEFAULT 0; 
    discount DECIMAL(10,2) DEFAULT 0;
    qty INT DEFAULT 1; -- Assuming a default quantity of 1
    qty_delivered DECIMAL(10,2) DEFAULT 0; 
    qty_to_invoice DECIMAL(10,2) DEFAULT 0; 
    purchase_id INT DEFAULT NULL;  
    create_uid INT DEFAULT NULL; 
    update_uid INT DEFAULT NULL; 
    create_date TIMESTAMP := NOW(); 
    update_date TIMESTAMP DEFAULT NULL; 
    diamond_length DECIMAL(10,2) DEFAULT NULL; 
    modeling_count INT DEFAULT NULL; 
    modeling_size DECIMAL(10,2) DEFAULT NULL; 
    master_size DECIMAL(10,2) DEFAULT NULL; 
    min_size DECIMAL(10,2) DEFAULT NULL;

BEGIN
    -- Get the next line number for the order
    SELECT COALESCE(MAX(sol.line_number), 0) + 1 INTO line_number
    FROM sale_order_line sol
    WHERE sol.sale_order_id = order_id;

    -- Get the price unit based on partner ID (assuming partner_id is known)
    SELECT COALESCE(MAX(pr.price_unit), 0) INTO price_unit
    FROM sale_price pr
        JOIN partner_group pg ON pr.partner_group_id = pg.id
        JOIN partner p ON p.partner_group_id = pg.id
        WHERE p.id = (SELECT partner_id FROM sale_order WHERE id = order_id);

    -- Insert into the sale_order_line table and get the new ID
    INSERT INTO public.sale_order_line (
        sale_order_id, product_description, line_number, price_unit,
        price_subtotal, price_tax, price_total,
        price_reduce, price_reduce_taxinc,
        price_reduce_taxexcl, discount, product_id,
        qty, qty_delivered, qty_to_invoice,
        purchase_id, update_uid, create_date,
        update_date, diamond_length, modeling_count,
        modeling_size, master_size,
        min_size, detail_uom_id
    )
    VALUES (
        order_id, product_description, line_number, price_unit,
        price_subtotal, price_tax, price_total,
        price_reduce, price_reduce_taxinc,
        price_reduce_taxexcl, discount,
        product_id, qty,
        qty_delivered, qty_to_invoice,
        purchase_id,
        update_uid, create_date,
        update_date,
        diamond_length, modeling_count,
        modeling_size, master_size,
        min_size, detail_uom_id
    )
	RETURNING id INTO order_line_id;

	-- Update the newly inserted record with the correct price unit if applicable
UPDATE sale_order_line a
SET price_unit = pg.price_unit
from sale_order so 
JOIN partner pa ON so.partner_id = pa.id
JOIN price_group pg ON pg.partner_group_id = pa.partner_group_id 
WHERE 
 a.sale_order_id = so.id and 
a.id = order_line_id    AND pg.product_id = a.product_id
  AND pg.type = 'sell';

END;
$$;


ALTER PROCEDURE public.sp_saleorder_line_i(IN order_id integer, IN product_description character varying, IN product_id integer, IN project_name character varying, IN detail_uom_id integer, OUT order_line_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_line_u(integer, character varying, integer, integer, numeric, numeric, numeric, numeric, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_line_u(IN iline_id integer, IN iproduct_description character varying, IN iproduct_id integer, IN ilinenumber integer, IN iprice_unit numeric, IN iprice_subtotal numeric, IN iprice_tax numeric, IN iprice_total numeric, IN iquantity integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the sale_order_line table
    UPDATE public.sale_order_line
    SET 
        product_description = COALESCE(iproduct_description, product_description),
        product_id = COALESCE(iproduct_id, product_id),
        line_number = COALESCE(ilinenumber, line_number),
        price_unit = COALESCE(iprice_unit, price_unit),
        price_subtotal = COALESCE(iprice_subtotal, price_subtotal),
        price_tax = COALESCE(iprice_tax, price_tax),
        price_total = COALESCE(iprice_total, price_total),
        qty = COALESCE(iquantity, qty)
    WHERE id = iline_id;  -- Update the record with the given line ID

    -- Optional: Raise a notice if no record was found
    IF NOT FOUND THEN
        RAISE NOTICE 'No record found with line ID: %', iline_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_line_u(IN iline_id integer, IN iproduct_description character varying, IN iproduct_id integer, IN ilinenumber integer, IN iprice_unit numeric, IN iprice_subtotal numeric, IN iprice_tax numeric, IN iprice_total numeric, IN iquantity integer) OWNER TO postgres;

--
-- Name: sp_saleorder_s(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_s(IN order_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    order_details RECORD;  -- Record type to hold query results
BEGIN
    -- Select statement to retrieve sale order details
    SELECT 
        so.id AS order_id,
        so.order_number,
        so.partner_id,
        so.create_date,
        so.state_id,
        so.amount_total,
        so.currency_id,
        sol.line_number,
        sol.product_id,
        sol.price_unit,
        sol.qty,
        sol.discount
    INTO order_details
    FROM public.sale_order so
    LEFT JOIN public.sale_order_line sol ON so.id = sol.order_id
    WHERE so.id = order_id;

    -- Check if any record was found
    IF NOT FOUND THEN
        RAISE NOTICE 'No sale order found with ID: %', order_id;
        RETURN;
    END IF;

    -- Output the results (you can customize this as needed)
    RAISE NOTICE 'Order ID: %, Order Number: %, Partner ID: %, Total Amount: %, Currency ID: %',
                 order_details.order_id, 
                 order_details.order_number, 
                 order_details.partner_id, 
                 order_details.amount_total, 
                 order_details.currency_id;

END;
$$;


ALTER PROCEDURE public.sp_saleorder_s(IN order_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_state_acceptpay_u(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_acceptpay_u(IN order_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the sale order exists
    IF NOT EXISTS (SELECT 1 FROM public.sale_order WHERE id = order_id) THEN
        RAISE EXCEPTION 'Sale order with ID % does not exist', order_id;
    END IF;

    -- Update the sale_order table to set the state to 14 (Qsent)
    UPDATE public.sale_order
    SET state = 3  -- SOD
    WHERE id = order_id;

-- درصورت پرداخت به صورت فیش یا انلاین این بخش توسط ادمین تایید میگردد
-- در بخش مالی نیاز به نگهداری اسناد پرداخت میباشد

END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_acceptpay_u(IN order_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_state_partner_rfq_u(integer, character varying, character varying, integer, integer, jsonb, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_partner_rfq_u(IN order_id integer, IN project_name character varying, IN note character varying, IN user_id integer, IN shipping_id integer, IN order_line_updates jsonb, IN line_detail_updates jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    line_id INT;
    detail_id INT;
BEGIN
    -- Update the sale_order table
    UPDATE public.sale_order
    SET 
        project_name = project_name,
        note = note,
        update_date = NOW(),
        update_uid = user_id,
        shipping_id = shipping_id  -- Updating shipping ID as well
    WHERE id = order_id;

    -- Update or insert sale_order_line entries based on the JSONB input
    FOR line_id IN SELECT (line->>'id')::INT FROM jsonb_array_elements(order_line_updates) AS line LOOP
        IF EXISTS (SELECT 1 FROM public.sale_order_line WHERE id = line_id) THEN
            -- Update existing line
            UPDATE public.sale_order_line
            SET 
                product_description = (line->>'product_description')::INT,
                product_id = (line->>'product_id')::INT,
                price_unit = (line->>'price_unit')::DECIMAL,
                qty = (line->>'qty')::INT,
                uom_id = (line->>'uom_id')::INT,  -- Assuming uom_id is passed in JSON
                discount = (line->>'discount')::DECIMAL,
                detail_uom_id = (line->>'detail_uom_id')::INT,  -- Assuming detail_uom_id is passed in JSON
                update_date = NOW(),
                update_uid = user_id  -- Set the user who updated the record
            WHERE id = line_id;
        ELSE
            -- Insert new record if it does not exist
            INSERT INTO public.sale_order_line (
                order_id, 
                product_description, 
                product_id, 
                price_unit, 
                qty, 
                uom_id, 
                discount, 
                create_date, 
                update_date, 
                create_uid, 
                update_uid,
                line_number
            )
            VALUES (
                order_id, 
                (line->>'product_description')::INT,
                (line->>'product_id')::INT,
                (line->>'price_unit')::DECIMAL,
                (line->>'qty')::INT,
                (line->>'uom_id')::INT,
                (line->>'discount')::DECIMAL,
                NOW(),  -- Create date is now for new records
                NOW(),
                user_id,  -- User creating the record
                user_id,  -- User updating the record
                (line->>'line_number')::INT  -- Assuming this is provided in JSON for new records
            );
        END IF;
    END LOOP;

    -- Update or insert sale_order_line_detail entries based on the JSONB input
    FOR detail_id IN SELECT (detail->>'id')::INT FROM jsonb_array_elements(line_detail_updates) AS detail LOOP
        IF EXISTS (SELECT 1 FROM public.sale_order_line_detail WHERE id = detail_id) THEN
            -- Update existing detail
            UPDATE public.sale_order_line_detail
            SET 
                width = (detail->>'width')::DECIMAL,
                height = (detail->>'height')::DECIMAL,
                cnt = (detail->>'cnt')::INT,
                code = detail->>'code',
                fitter_type = detail->>'fitter_type',
                update_date = NOW()
            WHERE id = detail_id;
        ELSE
            -- Insert new record if it does not exist; assuming order_line_id corresponds to an existing sale_order_line ID.
            INSERT INTO public.sale_order_line_detail (
                order_line_id, 
                width, 
                height, 
                cnt, 
                code, 
                fitter_type, 
                create_date, 
                update_date
            )
            VALUES (
                detail_id,  -- This should reference the corresponding sale_order_line ID; adjust as necessary.
                (detail->>'width')::DECIMAL,
                (detail->>'height')::DECIMAL,
                (detail->>'cnt')::INT,
                detail->>'code',
                detail->>'fitter_type',
                NOW(),  -- Create date is now for new records
                NOW()
            );
        END IF;
    END LOOP;

END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_partner_rfq_u(IN order_id integer, IN project_name character varying, IN note character varying, IN user_id integer, IN shipping_id integer, IN order_line_updates jsonb, IN line_detail_updates jsonb) OWNER TO postgres;

--
-- Name: sp_saleorder_state_qsent_u(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_qsent_u(IN order_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    line_id INT;
    detail_id INT;
BEGIN
    -- Check if the sale order exists
    IF NOT EXISTS (SELECT 1 FROM public.sale_order WHERE id = order_id) THEN
        RAISE EXCEPTION 'Sale order with ID % does not exist', order_id;
    END IF;

    -- Update the sale_order table to set the state to 1
    UPDATE public.sale_order
    SET state = 13 --Qsent
    WHERE id = order_id;

    
END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_qsent_u(IN order_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_state_qutation_u(integer, numeric); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_qutation_u(IN p_id integer, IN unitprice numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the price_unit for the specified sale_order_line
    UPDATE sale_order_line
    SET price_unit = unitPrice
    WHERE id = p_id;

    -- Optionally, you can add a check to see if any rows were updated
    IF NOT FOUND THEN
        RAISE NOTICE 'No sale order line found with id: %', p_id;
    END IF;

END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_qutation_u(IN p_id integer, IN unitprice numeric) OWNER TO postgres;

--
-- Name: sp_saleorder_state_rfq_u(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_rfq_u(IN p_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    cnt INT;  -- Declare a variable to hold the count
BEGIN
    -- Count the number of sale orders with state_id != 0 for the current year
    SELECT COUNT(*) INTO cnt
    FROM sale_order
    WHERE state_id != 0 AND EXTRACT(YEAR FROM create_date) = EXTRACT(YEAR FROM CURRENT_DATE);

    -- Update the sale order with the new state and order number
    UPDATE sale_order
    SET state_id = 1, order_number = 'SO-' || (cnt + 1)  -- Use || for string concatenation
    WHERE id = p_id;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_rfq_u(IN p_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_state_sign_u(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_sign_u(IN order_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the sale order exists
    IF NOT EXISTS (SELECT 1 FROM public.sale_order WHERE id = order_id) THEN
        RAISE EXCEPTION 'Sale order with ID % does not exist', order_id;
    END IF;

    -- Update the sale_order table to set the state to 14 (Qsent)
    UPDATE public.sale_order
    SET state = 14  -- Qsent
    WHERE id = order_id;

    -- Check if the partner is in the VIP group
    IF EXISTS (
        SELECT 1 
        FROM public.sale_order so
        JOIN public.partner p ON p.id = so.partner_id
        JOIN public.partner_group pg ON p.group_id = pg.id
        WHERE so.id = order_id AND pg.name = 'VIP'
    ) THEN 
        -- Update the sale_order state to 3 (ORD)
        UPDATE public.sale_order
        SET state = 3  -- ORD
        WHERE id = order_id;
    
    ELSE 
        -- If not VIP, update the state to 15 (PayNeed)
        UPDATE public.sale_order
        SET state = 15  -- PayNeed   
        WHERE id = order_id;
    END IF;

END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_sign_u(IN order_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_state_user_rfq__u(integer, character varying, character varying, integer, integer, integer, jsonb, jsonb); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_state_user_rfq__u(IN order_id integer, IN project_name character varying, IN note character varying, IN user_id integer, IN shipping_id integer, IN currency_id integer, IN order_line_updates jsonb, IN line_detail_updates jsonb)
    LANGUAGE plpgsql
    AS $$
DECLARE
    line_id INT;
    detail_id INT;
BEGIN
    -- Update the sale_order table
    UPDATE public.sale_order
    SET 
        project_name = project_name,
        note = note,
        update_date = NOW(),
        update_uid = user_id,
        shipping_id = shipping_id,
        currency_id = currency_id ,
		state = 2 -- Qutation
		
    WHERE id = order_id;

    -- Update or insert sale_order_line entries based on the JSONB input
    FOR line_id IN SELECT (line->>'id')::INT FROM jsonb_array_elements(order_line_updates) AS line LOOP
        IF EXISTS (SELECT 1 FROM public.sale_order_line WHERE id = line_id) THEN
            -- Update existing line
            UPDATE public.sale_order_line
            SET 
                product_description = (line->>'product_description')::INT,
                product_id = (line->>'product_id')::INT,
                price_unit = (line->>'price_unit')::DECIMAL,
                qty = (line->>'qty')::INT,
                uom_id = (line->>'uom_id')::INT,  -- Assuming uom_id is passed in JSON
                discount = (line->>'discount')::DECIMAL,
                line_number = (line->>'line_number')::INT,  -- Assuming line_number is passed in JSON
                detail_uom_id = (line->>'detail_uom_id')::INT,  -- Assuming detail_uom_id is passed in JSON
                update_date = NOW(),
                update_uid = user_id  -- Set the user who updated the record
            WHERE id = line_id;
        ELSE
            -- Insert new record if it does not exist
            INSERT INTO public.sale_order_line (
                order_id, 
                product_description, 
                product_id, 
                price_unit, 
                qty, 
                uom_id, 
                discount, 
                line_number,
                detail_uom_id,
                create_date, 
                update_date, 
                create_uid, 
                update_uid
            )
            VALUES (
                order_id, 
                (line->>'product_description')::INT,
                (line->>'product_id')::INT,
                (line->>'price_unit')::DECIMAL,
                (line->>'qty')::INT,
                (line->>'uom_id')::INT,
                (line->>'discount')::DECIMAL,
                (line->>'line_number')::INT,  -- Assuming this is provided in JSON for new records
                (line->>'detail_uom_id')::INT,  -- Assuming this is provided in JSON for new records
                NOW(),  -- Create date is now for new records
                NOW(),
                user_id,  -- User creating the record
                user_id   -- User updating the record
            );
        END IF;
    END LOOP;

    -- Update or insert sale_order_line_detail entries based on the JSONB input
    FOR detail_id IN SELECT (detail->>'id')::INT FROM jsonb_array_elements(line_detail_updates) AS detail LOOP
        IF EXISTS (SELECT 1 FROM public.sale_order_line_detail WHERE id = detail_id) THEN
            -- Update existing detail
            UPDATE public.sale_order_line_detail
            SET 
                width = (detail->>'width')::DECIMAL,
                height = (detail->>'height')::DECIMAL,
                cnt = (detail->>'cnt')::INT,
                code = detail->>'code',
                fitter_type = detail->>'fitter_type',
                update_date = NOW()
            WHERE id = detail_id;
        ELSE
            -- Insert new record if it does not exist; assuming order_line_id corresponds to an existing sale_order_line ID.
            INSERT INTO public.sale_order_line_detail (
                order_line_id, 
                width, 
                height, 
                cnt, 
                code, 
                fitter_type, 
                create_date, 
                update_date
            )
            VALUES (
                detail_id,  -- This should reference the corresponding sale_order_line ID; adjust as necessary.
                (detail->>'width')::DECIMAL,
                (detail->>'height')::DECIMAL,
                (detail->>'cnt')::INT,
                detail->>'code',
                detail->>'fitter_type',
                NOW(),  -- Create date is now for new records
                NOW()
            );
        END IF;
    END LOOP;

END;
$$;


ALTER PROCEDURE public.sp_saleorder_state_user_rfq__u(IN order_id integer, IN project_name character varying, IN note character varying, IN user_id integer, IN shipping_id integer, IN currency_id integer, IN order_line_updates jsonb, IN line_detail_updates jsonb) OWNER TO postgres;

--
-- Name: sp_saleorder_u(integer, character varying, integer, character varying, character varying, numeric, numeric, numeric, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_u(IN iorder_id integer, IN iorder_number character varying, IN ipartner_id integer, IN iproject_name character varying, IN inote character varying, IN iamount_untaxed numeric, IN iamount_tax numeric, IN iamount_total numeric, IN icurrency_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the sale_order table
    UPDATE public.sale_order
    SET 
        order_number = CASE 
            WHEN iorder_number IS NOT NULL THEN iorder_number 
            ELSE sale_order.order_number 
        END,
        partner_id = CASE 
            WHEN ipartner_id IS NOT NULL THEN ipartner_id 
            ELSE sale_order.partner_id 
        END,
        project_name = CASE 
            WHEN iproject_name IS NOT NULL THEN iproject_name 
            ELSE sale_order.project_name 
        END,
        note = CASE 
            WHEN inote IS NOT NULL THEN inote 
            ELSE sale_order.note 
        END,
        amount_untaxed = CASE 
            WHEN iamount_untaxed IS NOT NULL THEN iamount_untaxed 
            ELSE sale_order.amount_untaxed 
        END,
        amount_tax = CASE 
            WHEN iamount_tax IS NOT NULL THEN iamount_tax 
            ELSE sale_order.amount_tax 
        END,
        amount_total = CASE 
            WHEN iamount_total IS NOT NULL THEN iamount_total 
            ELSE sale_order.amount_total 
        END,
        currency_id = CASE 
            WHEN icurrency_id IS NOT NULL THEN icurrency_id 
            ELSE sale_order.currency_id 
        END
    WHERE id = iorder_id;  -- Update the record with the given order ID

    -- Optional: Raise a notice if no record was found
    IF NOT FOUND THEN
        RAISE NOTICE 'No record found with order ID: %', iorder_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_u(IN iorder_id integer, IN iorder_number character varying, IN ipartner_id integer, IN iproject_name character varying, IN inote character varying, IN iamount_untaxed numeric, IN iamount_tax numeric, IN iamount_total numeric, IN icurrency_id integer) OWNER TO postgres;

--
-- Name: sp_saleorder_u(integer, character varying, character varying, character varying, character varying, numeric, numeric, numeric, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_saleorder_u(IN iorder_id integer, IN iorder_number character varying, IN ipartner_id character varying, IN iproject_name character varying, IN inote character varying, IN iamount_untaxed numeric, IN iamount_tax numeric, IN iamount_total numeric, IN icurrency_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the sale_order table
    UPDATE public.sale_order
    SET 
        order_number = CASE 
            WHEN iorder_number IS NOT NULL THEN iorder_number 
            ELSE sale_order.order_number 
        END,
        partner_id = CASE 
            WHEN ipartner_id IS NOT NULL THEN ipartner_id::character varying  -- Ensure it's character varying
            ELSE sale_order.partner_id 
        END,
        project_name = CASE 
            WHEN iproject_name IS NOT NULL THEN iproject_name 
            ELSE sale_order.project_name 
        END,
        note = CASE 
            WHEN inote IS NOT NULL THEN inote 
            ELSE sale_order.note 
        END,
        amount_untaxed = CASE 
            WHEN iamount_untaxed IS NOT NULL THEN iamount_untaxed 
            ELSE sale_order.amount_untaxed 
        END,
        amount_tax = CASE 
            WHEN iamount_tax IS NOT NULL THEN iamount_tax 
            ELSE sale_order.amount_tax 
        END,
        amount_total = CASE 
            WHEN iamount_total IS NOT NULL THEN iamount_total 
            ELSE sale_order.amount_total 
        END,
        currency_id = CASE 
            WHEN icurrency_id IS NOT NULL THEN icurrency_id::integer  -- Ensure it's integer
            ELSE sale_order.currency_id 
        END
    WHERE id = iorder_id;  -- Update the record with the given order ID

    -- Optional: Raise a notice if no record was found
    IF NOT FOUND THEN
        RAISE NOTICE 'No record found with order ID: %', iorder_id;
    END IF;
END;
$$;


ALTER PROCEDURE public.sp_saleorder_u(IN iorder_id integer, IN iorder_number character varying, IN ipartner_id character varying, IN iproject_name character varying, IN inote character varying, IN iamount_untaxed numeric, IN iamount_tax numeric, IN iamount_total numeric, IN icurrency_id integer) OWNER TO postgres;

--
-- Name: sp_uom_i(integer, character varying, numeric, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_uom_i(IN id integer, IN name character varying, IN value numeric, IN unit character varying, IN type character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Insert into the uom table
    INSERT INTO public.uom(
        id, name, value, unit, type)
    VALUES (
        id, name, value, unit, type
    );

    -- Optionally raise a notice to confirm insertion
    RAISE NOTICE 'Inserted UOM with ID: %', id;

END;
$$;


ALTER PROCEDURE public.sp_uom_i(IN id integer, IN name character varying, IN value numeric, IN unit character varying, IN type character varying) OWNER TO postgres;

--
-- Name: sp_vendor_s(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.sp_vendor_s()
    LANGUAGE plpgsql
    AS $$
BEGIN

   SELECT  id, name
	FROM public.partner;
END;
$$;


ALTER PROCEDURE public.sp_vendor_s() OWNER TO postgres;

--
-- Name: spsale_order_lines_s(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.spsale_order_lines_s()
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Create a temporary table to hold the results
    CREATE TEMP TABLE temp_sale_order_lines AS
    SELECT 
        sale_order_id, 
        product_description, 
        line_number, 
        price_unit, 
        price_subtotal, 
        price_tax, 
        price_total, 
        price_reduce, 
        price_reduce_taxinc, 
        price_reduce_taxexcl, 
        discount, 
        product_id, 
        qty, 
        uom_id, 
        qty_delivered, 
        qty_to_invoice, 
        purchase_id, 
        create_uid, 
        create_date, 
        update_date, 
        diamond, 
        modeling, 
        modeling_size, 
        master_size, 
        min_size, 
        detail_uom_id,
        update_uid,
        id
    FROM public.sale_order_line;

    -- Optionally: You can perform additional operations here or return the results.
END;
$$;


ALTER PROCEDURE public.spsale_order_lines_s() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.address (
    partner_id integer,
    address character(100),
    title character(100),
    location character(100),
    isdefault boolean,
    id integer NOT NULL
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: Address_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Address_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Address_id_seq" OWNER TO postgres;

--
-- Name: Address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Address_id_seq" OWNED BY public.address.id;


--
-- Name: messangers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messangers (
    name character(100),
    link character(200),
    active bit(1),
    username character(100),
    password character(100),
    id integer NOT NULL
);


ALTER TABLE public.messangers OWNER TO postgres;

--
-- Name: Messangers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."Messangers_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public."Messangers_id_seq" OWNER TO postgres;

--
-- Name: Messangers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."Messangers_id_seq" OWNED BY public.messangers.id;


--
-- Name: access_role; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.access_role (
);


ALTER TABLE public.access_role OWNER TO postgres;

--
-- Name: account; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account (
    account_no character(100),
    name character(100),
    account_type bit(1),
    id integer NOT NULL
);


ALTER TABLE public.account OWNER TO postgres;

--
-- Name: account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.account_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.account_id_seq OWNER TO postgres;

--
-- Name: account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.account_id_seq OWNED BY public.account.id;


--
-- Name: attachment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.attachment (
    name character(100),
    path character(100),
    id integer NOT NULL
);


ALTER TABLE public.attachment OWNER TO postgres;

--
-- Name: attachment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.attachment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.attachment_id_seq OWNER TO postgres;

--
-- Name: attachment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.attachment_id_seq OWNED BY public.attachment.id;


--
-- Name: check_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.check_detail (
    partner_payment_id integer,
    "shenase sayadi" integer,
    due_date date,
    sender_name character(100),
    reciver_name character(100),
    serial_no integer,
    accepted bit(1),
    id integer NOT NULL
);


ALTER TABLE public.check_detail OWNER TO postgres;

--
-- Name: check_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.check_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.check_detail_id_seq OWNER TO postgres;

--
-- Name: check_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.check_detail_id_seq OWNED BY public.check_detail.id;


--
-- Name: company; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.company (
    type_id integer,
    name character(100),
    "Tell" numeric(11,0),
    mobile numeric(11,0),
    address character(100),
    email character(20),
    id integer NOT NULL
);


ALTER TABLE public.company OWNER TO postgres;

--
-- Name: company_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.company_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.company_id_seq OWNER TO postgres;

--
-- Name: company_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.company_id_seq OWNED BY public.company.id;


--
-- Name: company_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.company_type (
);


ALTER TABLE public.company_type OWNER TO postgres;

--
-- Name: currency; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.currency (
    name character(10),
    id integer NOT NULL
);


ALTER TABLE public.currency OWNER TO postgres;

--
-- Name: currency_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.currency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.currency_id_seq OWNER TO postgres;

--
-- Name: currency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.currency_id_seq OWNED BY public.currency.id;


--
-- Name: custom_product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.custom_product (
    id integer NOT NULL,
    product_id integer,
    product_type_id integer[],
    assembly_id integer[]
);


ALTER TABLE public.custom_product OWNER TO postgres;

--
-- Name: file; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.file (
    id integer NOT NULL,
    file_name text,
    file_data bytea,
    file_type character varying(100),
    source_id integer
);


ALTER TABLE public.file OWNER TO postgres;

--
-- Name: file_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.file_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_id_seq OWNER TO postgres;

--
-- Name: file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.file_id_seq OWNED BY public.file.id;


--
-- Name: group_access; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_access (
    group_id integer,
    access_id integer,
    id integer NOT NULL
);


ALTER TABLE public.group_access OWNER TO postgres;

--
-- Name: group_access_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.group_access_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.group_access_id_seq OWNER TO postgres;

--
-- Name: group_access_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.group_access_id_seq OWNED BY public.group_access.id;


--
-- Name: main_query; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.main_query (
);


ALTER TABLE public.main_query OWNER TO postgres;

--
-- Name: partner; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partner (
    company_id integer,
    name character(100),
    email character(100),
    mobile numeric(11,0),
    partner_group_id integer,
    messanger_name character(100),
    messanger_link character(200),
    id integer NOT NULL
);


ALTER TABLE public.partner OWNER TO postgres;

--
-- Name: partner_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partner_group (
    name character(100),
    description character(500),
    type character(20),
    id integer NOT NULL
);


ALTER TABLE public.partner_group OWNER TO postgres;

--
-- Name: TABLE partner_group; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.partner_group IS 'این جدول برای گروه بندی مشتری برای  نحوه پرداخت (نقدی - اعتباری)Payment و لیست قیمت میباشد priceList';


--
-- Name: partner_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partner_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partner_group_id_seq OWNER TO postgres;

--
-- Name: partner_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partner_group_id_seq OWNED BY public.partner_group.id;


--
-- Name: partner_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partner_id_seq OWNER TO postgres;

--
-- Name: partner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partner_id_seq OWNED BY public.partner.id;


--
-- Name: partner_payment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partner_payment (
    partner_id integer,
    payment_type_id integer,
    payment_date date,
    amount numeric(12,2),
    debit_credit bit(1),
    partner_account_id integer,
    company_account_id integer,
    image bytea,
    description character(500),
    id integer NOT NULL
);


ALTER TABLE public.partner_payment OWNER TO postgres;

--
-- Name: partner_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partner_payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partner_payment_id_seq OWNER TO postgres;

--
-- Name: partner_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partner_payment_id_seq OWNED BY public.partner_payment.id;


--
-- Name: price_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.price_group (
    partner_group_id integer,
    product_id integer,
    price_unit numeric(10,2),
    discount_percent integer,
    type character(10),
    id integer NOT NULL
);


ALTER TABLE public.price_group OWNER TO postgres;

--
-- Name: TABLE price_group; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.price_group IS 'type -- > buy , sell';


--
-- Name: price_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.price_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.price_group_id_seq OWNER TO postgres;

--
-- Name: price_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.price_group_id_seq OWNED BY public.price_group.id;


--
-- Name: producing_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.producing_group (
    name character(100),
    description character(100),
    id integer NOT NULL
);


ALTER TABLE public.producing_group OWNER TO postgres;

--
-- Name: producing_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.producing_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.producing_group_id_seq OWNER TO postgres;

--
-- Name: producing_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.producing_group_id_seq OWNED BY public.producing_group.id;


--
-- Name: product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product (
    active boolean,
    barcode character varying,
    user_id integer,
    create_date timestamp without time zone,
    image_id integer,
    "saleORpurchase" integer DEFAULT 3,
    name character varying(100),
    id integer NOT NULL
);


ALTER TABLE public.product OWNER TO postgres;

--
-- Name: product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_id_seq OWNER TO postgres;

--
-- Name: product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_id_seq OWNED BY public.product.id;


--
-- Name: rel_groups_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rel_groups_state (
    id integer NOT NULL,
    group_id integer,
    state_id integer,
    line_number integer
);


ALTER TABLE public.rel_groups_state OWNER TO postgres;

--
-- Name: TABLE rel_groups_state; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.rel_groups_state IS 'وضعیت state های هر گروه محصول یا گروه مشتری را مشخص میکند- شامل چه مراحلی با چه ترتیبی';


--
-- Name: product_state_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_state_id_seq OWNER TO postgres;

--
-- Name: product_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_state_id_seq OWNED BY public.rel_groups_state.id;


--
-- Name: product_type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product_type (
    name character varying(20),
    value character varying(20),
    ename character varying(20),
    evalue character varying(20),
    id integer NOT NULL,
    related_product integer[]
);


ALTER TABLE public.product_type OWNER TO postgres;

--
-- Name: product_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_type_id_seq OWNER TO postgres;

--
-- Name: product_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_type_id_seq OWNED BY public.product_type.id;


--
-- Name: product_type_id_seq1; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_type_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_type_id_seq1 OWNER TO postgres;

--
-- Name: product_type_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_type_id_seq1 OWNED BY public.custom_product.id;


--
-- Name: purchase_order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_order (
    purchase_number character varying(255) NOT NULL,
    partner_id integer NOT NULL,
    create_date timestamp without time zone NOT NULL,
    state_id integer,
    user_id integer,
    bill_id integer,
    note text,
    chat_id integer,
    amount_untaxed numeric(15,2),
    amount_tax numeric(15,2),
    amount_total numeric(15,2),
    currency_id integer,
    signed_by character varying(255),
    signed_date timestamp without time zone,
    print_template_id integer,
    update_date timestamp without time zone,
    order_line_id integer,
    parent_id integer,
    group_id integer,
    product_state_id integer,
    id integer NOT NULL
);


ALTER TABLE public.purchase_order OWNER TO postgres;

--
-- Name: purchase_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.purchase_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.purchase_order_id_seq OWNER TO postgres;

--
-- Name: purchase_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.purchase_order_id_seq OWNED BY public.purchase_order.id;


--
-- Name: purchase_order_line; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_order_line (
    product_description character(100),
    line_number integer,
    price_unit numeric NOT NULL,
    price_subtotal numeric,
    price_tax numeric(10,2),
    price_total numeric,
    price_reduce numeric,
    price_reduce_taxinc numeric,
    price_reduce_taxexcl numeric,
    discount numeric,
    product_id integer,
    qty numeric NOT NULL,
    uom_id integer,
    qty_delivered numeric,
    qty_to_invoice numeric,
    purchase_id integer,
    customer_lead double precision NOT NULL,
    display_type character varying,
    create_uid integer,
    create_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    update_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    order_line_detail_id integer,
    diamond numeric(10,20),
    modeling integer,
    modeling_size numeric(10,20),
    master_size numeric(10,20),
    min_size integer,
    detail_uom_id integer,
    producing_state_id integer,
    producing_group_id integer,
    id integer NOT NULL
);


ALTER TABLE public.purchase_order_line OWNER TO postgres;

--
-- Name: purchase_order_line_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_order_line_detail (
    purchase_line_id integer NOT NULL,
    width numeric(5,1),
    height numeric(5,1),
    cnt integer,
    code character(10),
    fitter boolean,
    moddeling boolean,
    diamond boolean,
    master boolean,
    id integer NOT NULL
);


ALTER TABLE public.purchase_order_line_detail OWNER TO postgres;

--
-- Name: purchase_order_line_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.purchase_order_line_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.purchase_order_line_detail_id_seq OWNER TO postgres;

--
-- Name: purchase_order_line_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.purchase_order_line_detail_id_seq OWNED BY public.purchase_order_line_detail.id;


--
-- Name: purchase_order_line_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.purchase_order_line_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.purchase_order_line_id_seq OWNER TO postgres;

--
-- Name: purchase_order_line_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.purchase_order_line_id_seq OWNED BY public.purchase_order_line.id;


--
-- Name: purchase_vendor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.purchase_vendor (
    id integer NOT NULL,
    purchase_id integer,
    vendor_id integer,
    is_selected bit(1),
    factor_file bytea
);


ALTER TABLE public.purchase_vendor OWNER TO postgres;

--
-- Name: purchase_vendor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.purchase_vendor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.purchase_vendor_id_seq OWNER TO postgres;

--
-- Name: purchase_vendor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.purchase_vendor_id_seq OWNED BY public.purchase_vendor.id;


--
-- Name: sale_order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_order (
    order_number character varying(255) NOT NULL,
    partner_id integer NOT NULL,
    create_date timestamp without time zone,
    state_id integer,
    create_uid integer,
    shipping_id integer,
    project_name character varying(255),
    note text,
    chat_id integer,
    amount_untaxed numeric(15,2),
    amount_tax numeric(15,2),
    amount_total numeric(15,2),
    currency_id integer,
    signed_date timestamp without time zone,
    access_token character varying(255),
    print_template_id integer,
    update_date timestamp without time zone,
    signed_by_id integer,
    update_uid integer,
    id integer NOT NULL,
    payment_method character varying(1)
);


ALTER TABLE public.sale_order OWNER TO postgres;

--
-- Name: sale_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_order_id_seq OWNER TO postgres;

--
-- Name: sale_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_order_id_seq OWNED BY public.sale_order.id;


--
-- Name: sale_order_line; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_order_line (
    sale_order_id integer NOT NULL,
    product_description character varying(100),
    line_number integer,
    price_unit numeric,
    price_subtotal numeric,
    price_tax numeric(10,2),
    price_total numeric,
    price_reduce numeric,
    price_reduce_taxinc numeric,
    price_reduce_taxexcl numeric,
    discount numeric,
    product_id integer,
    qty numeric NOT NULL,
    uom_id integer,
    qty_delivered numeric,
    qty_to_invoice numeric,
    purchase_id integer,
    create_uid integer,
    create_date timestamp without time zone,
    update_date timestamp without time zone,
    diamond_length numeric(10,20),
    modeling_count integer,
    modeling_size numeric(10,20),
    master_size numeric(10,20),
    min_size integer,
    detail_uom_id integer,
    update_uid integer,
    id integer NOT NULL
);


ALTER TABLE public.sale_order_line OWNER TO postgres;

--
-- Name: sale_order_line_detail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_order_line_detail (
    order_line_id integer NOT NULL,
    width numeric(5,1),
    height numeric(5,1),
    cnt integer,
    code character(10),
    fitter boolean,
    modeling boolean,
    diamond boolean,
    master boolean,
    id integer NOT NULL
);


ALTER TABLE public.sale_order_line_detail OWNER TO postgres;

--
-- Name: sale_order_line_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_order_line_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_order_line_detail_id_seq OWNER TO postgres;

--
-- Name: sale_order_line_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_order_line_detail_id_seq OWNED BY public.sale_order_line_detail.id;


--
-- Name: sale_order_line_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_order_line_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_order_line_id_seq OWNER TO postgres;

--
-- Name: sale_order_line_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_order_line_id_seq OWNED BY public.sale_order_line.id;


--
-- Name: sale_price; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_price (
    id integer NOT NULL,
    product_id integer,
    partner_group_id integer,
    price_unit numeric(10,2)
);


ALTER TABLE public.sale_price OWNER TO postgres;

--
-- Name: sale_price_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_price_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_price_id_seq OWNER TO postgres;

--
-- Name: sale_price_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_price_id_seq OWNED BY public.sale_price.id;


--
-- Name: state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.state (
    id integer NOT NULL,
    type character varying(10),
    title character varying(10),
    description character varying(100),
    "order" integer
);


ALTER TABLE public.state OWNER TO postgres;

--
-- Name: state_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.state_id_seq OWNER TO postgres;

--
-- Name: state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.state_id_seq OWNED BY public.state.id;


--
-- Name: uom; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.uom (
    id integer NOT NULL,
    name character(10),
    value character(10),
    unit numeric(10,5),
    type integer
);


ALTER TABLE public.uom OWNER TO postgres;

--
-- Name: uom_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.uom_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.uom_id_seq OWNER TO postgres;

--
-- Name: uom_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.uom_id_seq OWNED BY public.uom.id;


--
-- Name: user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."user" (
    group_id integer,
    id integer NOT NULL,
    name character(100)
);


ALTER TABLE public."user" OWNER TO postgres;

--
-- Name: user_group; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_group (
);


ALTER TABLE public.user_group OWNER TO postgres;

--
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_id_seq OWNER TO postgres;

--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.user_id_seq OWNED BY public."user".id;


--
-- Name: warehouse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.warehouse (
);


ALTER TABLE public.warehouse OWNER TO postgres;

--
-- Name: account id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account ALTER COLUMN id SET DEFAULT nextval('public.account_id_seq'::regclass);


--
-- Name: address id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.address ALTER COLUMN id SET DEFAULT nextval('public."Address_id_seq"'::regclass);


--
-- Name: attachment id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attachment ALTER COLUMN id SET DEFAULT nextval('public.attachment_id_seq'::regclass);


--
-- Name: check_detail id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.check_detail ALTER COLUMN id SET DEFAULT nextval('public.check_detail_id_seq'::regclass);


--
-- Name: company id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company ALTER COLUMN id SET DEFAULT nextval('public.company_id_seq'::regclass);


--
-- Name: currency id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.currency ALTER COLUMN id SET DEFAULT nextval('public.currency_id_seq'::regclass);


--
-- Name: custom_product id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custom_product ALTER COLUMN id SET DEFAULT nextval('public.product_type_id_seq1'::regclass);


--
-- Name: file id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file ALTER COLUMN id SET DEFAULT nextval('public.file_id_seq'::regclass);


--
-- Name: group_access id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_access ALTER COLUMN id SET DEFAULT nextval('public.group_access_id_seq'::regclass);


--
-- Name: messangers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messangers ALTER COLUMN id SET DEFAULT nextval('public."Messangers_id_seq"'::regclass);


--
-- Name: partner id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner ALTER COLUMN id SET DEFAULT nextval('public.partner_id_seq'::regclass);


--
-- Name: partner_group id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner_group ALTER COLUMN id SET DEFAULT nextval('public.partner_group_id_seq'::regclass);


--
-- Name: partner_payment id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner_payment ALTER COLUMN id SET DEFAULT nextval('public.partner_payment_id_seq'::regclass);


--
-- Name: price_group id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price_group ALTER COLUMN id SET DEFAULT nextval('public.price_group_id_seq'::regclass);


--
-- Name: producing_group id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producing_group ALTER COLUMN id SET DEFAULT nextval('public.producing_group_id_seq'::regclass);


--
-- Name: product id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product ALTER COLUMN id SET DEFAULT nextval('public.product_id_seq'::regclass);


--
-- Name: product_type id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_type ALTER COLUMN id SET DEFAULT nextval('public.product_type_id_seq'::regclass);


--
-- Name: purchase_order id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order ALTER COLUMN id SET DEFAULT nextval('public.purchase_order_id_seq'::regclass);


--
-- Name: purchase_order_line id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_line ALTER COLUMN id SET DEFAULT nextval('public.purchase_order_line_id_seq'::regclass);


--
-- Name: purchase_order_line_detail id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_line_detail ALTER COLUMN id SET DEFAULT nextval('public.purchase_order_line_detail_id_seq'::regclass);


--
-- Name: purchase_vendor id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_vendor ALTER COLUMN id SET DEFAULT nextval('public.purchase_vendor_id_seq'::regclass);


--
-- Name: rel_groups_state id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_groups_state ALTER COLUMN id SET DEFAULT nextval('public.product_state_id_seq'::regclass);


--
-- Name: sale_order id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order ALTER COLUMN id SET DEFAULT nextval('public.sale_order_id_seq'::regclass);


--
-- Name: sale_order_line id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_line ALTER COLUMN id SET DEFAULT nextval('public.sale_order_line_id_seq'::regclass);


--
-- Name: sale_order_line_detail id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_line_detail ALTER COLUMN id SET DEFAULT nextval('public.sale_order_line_detail_id_seq'::regclass);


--
-- Name: sale_price id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_price ALTER COLUMN id SET DEFAULT nextval('public.sale_price_id_seq'::regclass);


--
-- Name: state id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.state ALTER COLUMN id SET DEFAULT nextval('public.state_id_seq'::regclass);


--
-- Name: uom id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uom ALTER COLUMN id SET DEFAULT nextval('public.uom_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user" ALTER COLUMN id SET DEFAULT nextval('public.user_id_seq'::regclass);


--
-- Data for Name: access_role; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.access_role  FROM stdin;
\.


--
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.account (account_no, name, account_type, id) FROM stdin;
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.address (partner_id, address, title, location, isdefault, id) FROM stdin;
1	تهران- خیابان اول                                                                                   	کارخانه 1                                                                                           	jlkfjsdklfj                                                                                         	t	2
\.


--
-- Data for Name: attachment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.attachment (name, path, id) FROM stdin;
trdt                                                                                                	ttttt                                                                                               	6
Image16                                                                                             	\N	7
\.


--
-- Data for Name: check_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.check_detail (partner_payment_id, "shenase sayadi", due_date, sender_name, reciver_name, serial_no, accepted, id) FROM stdin;
\.


--
-- Data for Name: company; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.company (type_id, name, "Tell", mobile, address, email, id) FROM stdin;
\N	آذران                                                                                               	21333333	9123333	تهران خیابان آزادی                                                                                  	n@gmail.com         	1
\.


--
-- Data for Name: company_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.company_type  FROM stdin;
\.


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.currency (name, id) FROM stdin;
\.


--
-- Data for Name: custom_product; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.custom_product (id, product_id, product_type_id, assembly_id) FROM stdin;
1	6	{1,5,9}	{1}
6	5	{1,3,5}	{4,1}
7	6	{1,4,8}	{4,1}
8	6	{1,4,8}	{5}
3	5	{1,3,5}	{3}
4	5	{1,3,5}	{4,2}
5	5	{1,3,5}	{4,2}
2	5	{1,3,5}	{2}
9	6	{1,4,8}	{4,2}
\.


--
-- Data for Name: file; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.file (id, file_name, file_data, file_type, source_id) FROM stdin;
\.


--
-- Data for Name: group_access; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_access (group_id, access_id, id) FROM stdin;
\.


--
-- Data for Name: main_query; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.main_query  FROM stdin;
\.


--
-- Data for Name: messangers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messangers (name, link, active, username, password, id) FROM stdin;
\.


--
-- Data for Name: partner; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.partner (company_id, name, email, mobile, partner_group_id, messanger_name, messanger_link, id) FROM stdin;
1	شاکری                                                                                               	sh@gmail.com                                                                                        	9125555	1	\N	\N	1
\.


--
-- Data for Name: partner_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.partner_group (name, description, type, id) FROM stdin;
VIP                                                                                                 	مشتری ویژه                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          	customer_payment    	1
normal                                                                                              	مشتری عادی                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          	customer_payment    	2
nasab                                                                                               	نصاب                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                	priceList           	3
other                                                                                               	متفرقه                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              	priceList           	4
normal                                                                                              	وندور عادی                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          	vendor_payment      	5
VIP                                                                                                 	وندور ویژه                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          	vendor_payment      	6
\.


--
-- Data for Name: partner_payment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.partner_payment (partner_id, payment_type_id, payment_date, amount, debit_credit, partner_account_id, company_account_id, image, description, id) FROM stdin;
\.


--
-- Data for Name: price_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.price_group (partner_group_id, product_id, price_unit, discount_percent, type, id) FROM stdin;
1	2	152.00	0	sell      	1
\.


--
-- Data for Name: producing_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.producing_group (name, description, id) FROM stdin;
\.


--
-- Data for Name: product; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.product (active, barcode, user_id, create_date, image_id, "saleORpurchase", name, id) FROM stdin;
t	\N	1	2024-12-04 05:02:51.754188	6	1	شیشه خم	5
t	101	\N	\N	\N	3	شیشه 	1
t	102	1	\N	\N	3	شیشه دوجداره	6
t	\N	1	2024-12-16 03:47:42.723356	7	1	P16	7
\.


--
-- Data for Name: product_type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.product_type (name, value, ename, evalue, id, related_product) FROM stdin;
نوع	خام	noe	kham	1	{6,5,1}
نوع	سکوریت	noe	secorit	2	{6,5,1}
ضخامت	4mm	thickness	\N	3	{6,5,1}
ضخامت	5mm	thickness	\N	4	{6,5,1}
نوع	نیمه سکوریت	noe	nimesecorit	6	{6,5,1}
رنگ	فلوت	color	\N	8	{6,5,1}
رنگ	سوپر کلیر	color	\N	9	{6,5,1}
نوع محصول	مصرفی	noe mahsool	masrafi	5	\N
ضخامت	10mm			10	\N
ضخامت	6mm	thickness	\N	7	{6,5,1}
\.


--
-- Data for Name: purchase_order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.purchase_order (purchase_number, partner_id, create_date, state_id, user_id, bill_id, note, chat_id, amount_untaxed, amount_tax, amount_total, currency_id, signed_by, signed_date, print_template_id, update_date, order_line_id, parent_id, group_id, product_state_id, id) FROM stdin;
\.


--
-- Data for Name: purchase_order_line; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.purchase_order_line (product_description, line_number, price_unit, price_subtotal, price_tax, price_total, price_reduce, price_reduce_taxinc, price_reduce_taxexcl, discount, product_id, qty, uom_id, qty_delivered, qty_to_invoice, purchase_id, customer_lead, display_type, create_uid, create_date, update_date, order_line_detail_id, diamond, modeling, modeling_size, master_size, min_size, detail_uom_id, producing_state_id, producing_group_id, id) FROM stdin;
\.


--
-- Data for Name: purchase_order_line_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.purchase_order_line_detail (purchase_line_id, width, height, cnt, code, fitter, moddeling, diamond, master, id) FROM stdin;
\.


--
-- Data for Name: purchase_vendor; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.purchase_vendor (id, purchase_id, vendor_id, is_selected, factor_file) FROM stdin;
\.


--
-- Data for Name: rel_groups_state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rel_groups_state (id, group_id, state_id, line_number) FROM stdin;
1	1	10	1
2	1	11	2
3	1	12	3
4	2	10	1
5	2	12	2
\.


--
-- Data for Name: sale_order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sale_order (order_number, partner_id, create_date, state_id, create_uid, shipping_id, project_name, note, chat_id, amount_untaxed, amount_tax, amount_total, currency_id, signed_date, access_token, print_template_id, update_date, signed_by_id, update_uid, id, payment_method) FROM stdin;
SO-01	1	\N	1	\N	\N	تست 1	درخواست ویژه	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1	\N
SO01	1	2024-12-04 04:34:31.8486	0	\N	2	Test01	\N	\N	\N	\N	\N	1	\N	\N	\N	\N	\N	\N	2	\N
S004	1	2024-12-14 02:53:33.782417	0	\N	2	test004	\N	\N	\N	\N	\N	1	\N	\N	\N	\N	\N	\N	3	\N
101	1	2024-12-14 02:58:54.710085	0	\N	2	test1	00000	\N	0.00	0.00	0.00	1	\N	\N	\N	\N	\N	\N	4	\N
S0500	1	2024-12-15 03:17:13.743076	0	\N	2	Test500	\N	\N	\N	\N	\N	1	\N	\N	\N	\N	\N	\N	5	\N
ORD123	1	2024-12-18 04:22:08.321315	0	\N	2	Project Alpha	\N	\N	\N	\N	\N	1	\N	\N	\N	\N	\N	\N	6	\N
\.


--
-- Data for Name: sale_order_line; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sale_order_line (sale_order_id, product_description, line_number, price_unit, price_subtotal, price_tax, price_total, price_reduce, price_reduce_taxinc, price_reduce_taxexcl, discount, product_id, qty, uom_id, qty_delivered, qty_to_invoice, purchase_id, create_uid, create_date, update_date, diamond_length, modeling_count, modeling_size, master_size, min_size, detail_uom_id, update_uid, id) FROM stdin;
1	\N	1	100	\N	\N	\N	\N	\N	\N	\N	2	1	3	\N	\N	\N	1	\N	\N	\N	\N	\N	\N	\N	1	\N	1
2	test09	2	0	0	0.00	0	0.00	0.00	0.00	0.00	5	100	\N	0.00	0.00	\N	\N	2024-12-08 00:52:10.541998	\N	\N	\N	\N	\N	\N	1	\N	8
2	test120	3	0.00	0.00	0.00	0.00	0.00	0.00	0.00	0.00	1	1	\N	0.00	0.00	\N	\N	2024-12-15 02:43:04.682846	\N	\N	\N	\N	\N	\N	1	\N	10
2	test130	4	0.00	0.00	0.00	0.00	0.00	0.00	0.00	0.00	1	1	\N	0.00	0.00	\N	\N	2024-12-15 03:10:16.289067	\N	\N	\N	\N	\N	\N	1	\N	11
\.


--
-- Data for Name: sale_order_line_detail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sale_order_line_detail (order_line_id, width, height, cnt, code, fitter, modeling, diamond, master, id) FROM stdin;
1	2.0	25.0	25	A         	f	f	f	f	1
1	2.0	25.0	25	A         	f	f	f	f	2
2	2.0	25.0	25	A         	f	f	f	f	3
10	2.0	25.0	25	A         	f	f	f	f	4
10	2.0	25.0	25	A100      	f	f	f	f	6
\.


--
-- Data for Name: sale_price; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sale_price (id, product_id, partner_group_id, price_unit) FROM stdin;
\.


--
-- Data for Name: state; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.state (id, type, title, description, "order") FROM stdin;
1	sale_order	RFQ	درخواست پیش فاکتور	\N
2	sale_order	QUT	پیش فاکتور	\N
3	sale_order	ORD	فاکتور فروش	\N
4	sale order	INV	فاکتور حسابداری	\N
5	purchase	PRFQ	درخواست پیش فاکتور	\N
6	purchase	PQUT	پیش فاکتور	\N
7	purchase	PORD	فاکتور خرید	\N
8	purchase	BIL	فاکتور حسابداری	\N
10	producing	ING	درحال تولید	\N
11	producing	TED	آماده شده	\N
12	producing	STR	انبار شده	\N
13	sale_order	QSent	پیشفاکتور ارسال شده	\N
14	sale_order	Sign	پیشفاکتور امضا شده	\N
15	sale_order	PayNeed	نیاز به پرداخت	\N
17	purchase	DLV	تحویل شده	\N
19	purchase	PQUT	پیشفاکتور انتخاب شده	\N
20	purchase	PSign	پیشفاکتور امضا شده	\N
21	purchase	PPay	پرداخت فاکتور	\N
\.


--
-- Data for Name: uom; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.uom (id, name, value, unit, type) FROM stdin;
1	ملیمتر    	mm        	0.00100	1
2	سانتی متر 	cm        	0.01000	1
3	مترمربع   	M2        	1.00000	2
4	عدد       	number    	1.00000	2
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."user" (group_id, id, name) FROM stdin;
1	1	admin                                                                                               
\.


--
-- Data for Name: user_group; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_group  FROM stdin;
\.


--
-- Data for Name: warehouse; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.warehouse  FROM stdin;
\.


--
-- Name: Address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Address_id_seq"', 2, true);


--
-- Name: Messangers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."Messangers_id_seq"', 1, false);


--
-- Name: account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.account_id_seq', 1, false);


--
-- Name: attachment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.attachment_id_seq', 7, true);


--
-- Name: check_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.check_detail_id_seq', 1, false);


--
-- Name: company_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.company_id_seq', 1, true);


--
-- Name: currency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.currency_id_seq', 1, false);


--
-- Name: file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.file_id_seq', 1, false);


--
-- Name: group_access_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.group_access_id_seq', 1, false);


--
-- Name: partner_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.partner_group_id_seq', 6, true);


--
-- Name: partner_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.partner_id_seq', 1, true);


--
-- Name: partner_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.partner_payment_id_seq', 1, false);


--
-- Name: price_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.price_group_id_seq', 1, true);


--
-- Name: producing_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.producing_group_id_seq', 1, false);


--
-- Name: product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_id_seq', 7, true);


--
-- Name: product_state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_state_id_seq', 5, true);


--
-- Name: product_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_type_id_seq', 10, true);


--
-- Name: product_type_id_seq1; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.product_type_id_seq1', 9, true);


--
-- Name: purchase_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_order_id_seq', 1, false);


--
-- Name: purchase_order_line_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_order_line_detail_id_seq', 1, false);


--
-- Name: purchase_order_line_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_order_line_id_seq', 1, false);


--
-- Name: purchase_vendor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.purchase_vendor_id_seq', 1, false);


--
-- Name: sale_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_order_id_seq', 6, true);


--
-- Name: sale_order_line_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_order_line_detail_id_seq', 6, true);


--
-- Name: sale_order_line_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_order_line_id_seq', 11, true);


--
-- Name: sale_price_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sale_price_id_seq', 1, false);


--
-- Name: state_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.state_id_seq', 21, true);


--
-- Name: uom_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.uom_id_seq', 4, true);


--
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.user_id_seq', 1, true);


--
-- Name: address Address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.address
    ADD CONSTRAINT "Address_pkey" PRIMARY KEY (id);


--
-- Name: messangers Messangers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messangers
    ADD CONSTRAINT "Messangers_pkey" PRIMARY KEY (id);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: attachment attachment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.attachment
    ADD CONSTRAINT attachment_pkey PRIMARY KEY (id);


--
-- Name: check_detail check_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.check_detail
    ADD CONSTRAINT check_detail_pkey PRIMARY KEY (id);


--
-- Name: company company_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (id);


--
-- Name: currency currency_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (id);


--
-- Name: file file_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file
    ADD CONSTRAINT file_pkey PRIMARY KEY (id);


--
-- Name: group_access group_access_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_access
    ADD CONSTRAINT group_access_pkey PRIMARY KEY (id);


--
-- Name: partner_group partner_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner_group
    ADD CONSTRAINT partner_group_pkey PRIMARY KEY (id);


--
-- Name: partner_payment partner_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner_payment
    ADD CONSTRAINT partner_payment_pkey PRIMARY KEY (id);


--
-- Name: partner partner_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.partner
    ADD CONSTRAINT partner_pkey PRIMARY KEY (id);


--
-- Name: price_group price_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.price_group
    ADD CONSTRAINT price_group_pkey PRIMARY KEY (id);


--
-- Name: producing_group producing_group_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.producing_group
    ADD CONSTRAINT producing_group_pkey PRIMARY KEY (id);


--
-- Name: product product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);


--
-- Name: rel_groups_state product_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rel_groups_state
    ADD CONSTRAINT product_state_pkey PRIMARY KEY (id);


--
-- Name: product_type product_type_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product_type
    ADD CONSTRAINT product_type_pkey PRIMARY KEY (id);


--
-- Name: custom_product product_type_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.custom_product
    ADD CONSTRAINT product_type_pkey1 PRIMARY KEY (id);


--
-- Name: purchase_order_line_detail purchase_order_line_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_line_detail
    ADD CONSTRAINT purchase_order_line_detail_pkey PRIMARY KEY (id);


--
-- Name: purchase_order_line purchase_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order_line
    ADD CONSTRAINT purchase_order_line_pkey PRIMARY KEY (id);


--
-- Name: purchase_order purchase_order_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_order
    ADD CONSTRAINT purchase_order_pkey PRIMARY KEY (id);


--
-- Name: purchase_vendor purchase_vendor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.purchase_vendor
    ADD CONSTRAINT purchase_vendor_pkey PRIMARY KEY (id);


--
-- Name: sale_order_line_detail sale_order_line_detail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_line_detail
    ADD CONSTRAINT sale_order_line_detail_pkey PRIMARY KEY (id);


--
-- Name: sale_order_line sale_order_line_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_line
    ADD CONSTRAINT sale_order_line_pkey PRIMARY KEY (id);


--
-- Name: sale_order sale_order_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT sale_order_pkey PRIMARY KEY (id);


--
-- Name: sale_price sale_price_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_price
    ADD CONSTRAINT sale_price_pkey PRIMARY KEY (id);


--
-- Name: state state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.state
    ADD CONSTRAINT state_pkey PRIMARY KEY (id);


--
-- Name: uom uom_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.uom
    ADD CONSTRAINT uom_pkey PRIMARY KEY (id);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

