from db.db import Database


# Create database class
db = Database()


def recompute_heatmap(scenario_id):
    """Function to recompute heatmap when network is changed."""
    import time
    start = time.time()

    scenario_id = int(scenario_id)

    status_precomputed = db.select('''SELECT ways_heatmap_computed 
                FROM scenarios 
                WHERE scenario_id = %(scenario_id)s''', {"scenario_id": scenario_id})[0][0]

    if status_precomputed == True:
        return 'Scenario was already precomputed.'

    speed = 1.33
    max_cost = 1200

    # """Get userid for particular scenario_id"""
    userid = db.select('''SELECT userid FROM scenarios WHERE scenario_id = %(scenario_id)s''', {
                    "scenario_id": scenario_id})[0][0]

    # """Clean tables and define changed grids"""
    db.perform('''DELETE FROM reached_edges_heatmap 
    WHERE scenario_id = %(scenario_id)s;

    DELETE FROM area_isochrones_scenario
    WHERE scenario_id = %(scenario_id)s;
    
    DROP TABLE IF EXISTS changed_grids;
    CREATE TEMP TABLE changed_grids AS 
    SELECT * FROM find_changed_grids(%(scenario_id)s,%(speed)s*%(max_cost)s);''', {"scenario_id": scenario_id, "speed": speed, "max_cost": max_cost})

    # """Select changed grids"""
    changed_grids = db.select(
        'SELECT starting_points, gridids, section_id FROM changed_grids;')

    # """Loop throuch section and recompute grids"""
    for i in changed_grids:
        print(i[2])

        db.perform('''SELECT pgrouting_edges_heatmap(%(max_cost)s, 
        %(starting_points)s, %(speed)s, %(gridids)s, 2, 
        'walking_standard',%(userid)s, %(scenario_id)s, %(section_id)s)''',
                {"max_cost": [max_cost], "starting_points": i[0], "speed": speed, "gridids": i[1], "userid": userid, "scenario_id": scenario_id, "section_id": i[2]})

    gridids = db.select("""SELECT UNNEST(gridids) FROM changed_grids""")

    for g in gridids:
        db.perform("""SELECT compute_area_isochrone(%(grid_id)s,%(scenario_id)s)""", {
                "grid_id": g[0], "scenario_id": scenario_id})

    buffer_geom = db.select("""SELECT ST_AsText(ST_BUFFER(ST_UNION(geom),0.0014)) 
    FROM area_isochrones_scenario 
    WHERE scenario_id = %(scenario_id)s""", {"scenario_id": scenario_id})

    buffer_geom = buffer_geom[0][0]
    db.perform("""DELETE FROM reached_pois_heatmap r
    USING pois_userinput p
    WHERE ST_Intersects(p.geom,ST_SETSRID(ST_GeomFromText(%(buffer_geom)s), 4326))
    AND r.gid = p.gid
    AND r.scenario_id = %(scenario_id)s;""", {"buffer_geom": buffer_geom, "scenario_id": scenario_id})
    
    db.perform('''SELECT reached_pois_heatmap(ST_SETSRID(ST_GeomFromText(%(buffer_geom)s), 4326), 0.0014, 'scenario', %(scenario_id)s);''',{"buffer_geom": buffer_geom, "scenario_id": scenario_id})
    
    db.perform('''UPDATE scenarios 
                SET ways_heatmap_computed = TRUE 
                WHERE scenario_id = %(scenario_id)s''', {"scenario_id": scenario_id})

    return