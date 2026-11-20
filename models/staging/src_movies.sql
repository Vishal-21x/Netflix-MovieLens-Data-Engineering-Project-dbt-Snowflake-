WITH raw_movies AS(
    SELECT * FROM MOVIELENS.RAW.raw_movies
)
SELECT 
    moviesId AS movie_id,
    title,
    genres
FROM raw_movies