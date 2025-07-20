import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/models.dart/outlet_model.dart';
import 'dart:math';

import 'package:startup/outlets/outlet_details.dart';

class OutletRecommendationsScreen extends StatefulWidget {
  final String groupId;
  final String username;
  final String uid;

  const OutletRecommendationsScreen({
    Key? key,
    required this.groupId,
    required this.username,
    required this.uid,
  }) : super(key: key);

  @override
  State<OutletRecommendationsScreen> createState() => 
      _OutletRecommendationsScreenState();
}

class _OutletRecommendationsScreenState extends State<OutletRecommendationsScreen> 
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Outlet> _outlets = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isGridView = true;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  
  static final Map<String, List<Outlet>> _outletCache = {};

  // Color Palette
  static const Color _primaryGold = Color(0xFFD4AF37);
  static const Color _amber = Color(0xFFFFBF00);
  static const Color _bronze = Color(0xFFCD7F32);
  static const Color _darkBg = Color(0xFF0A0A0A);
  static const Color _cardBg = Color(0xFF1A1A1A);
  static const Color _borderColor = Color(0xFF2A2A2A);
  static const Color _textGrey = Color(0xFF888888);
  static const Color _lightGrey = Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    _fetchOutlets();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _fetchOutlets({bool forceRefresh = false}) async {
    final cacheKey = widget.groupId;
    
    if (!forceRefresh && _outletCache.containsKey(cacheKey)) {
      setState(() {
        _outlets = _outletCache[cacheKey]!;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      if (forceRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final QuerySnapshot snapshot = await _firestore.collection('outlets').get();
      print("🔥 Total docs fetched: ${snapshot.docs.length}");
      
      if (snapshot.docs.isNotEmpty) {
        List<Outlet> allOutlets = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          print("📄 Document data: $data"); // Debug print
          
          // Use the Outlet.fromFirestore factory method
          return Outlet.fromFirestore(data, doc.id);
        }).toList();

        // Filter out outlets with empty/invalid data
        allOutlets = allOutlets.where((outlet) => 
          outlet.name.isNotEmpty && 
          outlet.location.isNotEmpty
        ).toList();

        print("✅ Valid outlets after filtering: ${allOutlets.length}");

        if (allOutlets.isNotEmpty) {
          allOutlets.shuffle(Random());
          List<Outlet> randomOutlets = allOutlets.take(8).toList();

          _outletCache[cacheKey] = randomOutlets;

          setState(() {
            _outlets = randomOutlets;
            _isLoading = false;
            _isRefreshing = false;
          });
        } else {
          print("⚠️ No valid outlets found after filtering");
          setState(() {
            _outlets = [];
            _isLoading = false;
            _isRefreshing = false;
          });
        }
      } else {
        print("⚠️ No documents found in outlets collection");
        setState(() {
          _outlets = [];
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching outlets: $e");
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load outlets: $e', 
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: _bronze,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'discover outlets',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A), Color(0xFF000000)],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading ? _buildLoadingWidget() : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryGold.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8008).withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                      ).createShader(bounds),
                      child: Text(
                        'curated for you ${widget.username}! ✨',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'discover amazing places around and away from you',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _lightGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildViewToggle(),
              _buildRefreshButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_cardBg, _cardBg.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: _primaryGold.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            icon: Icons.grid_view_rounded,
            isSelected: _isGridView,
            onTap: () => setState(() => _isGridView = true),
          ),
          _buildToggleButton(
            icon: Icons.view_list_rounded,
            isSelected: !_isGridView,
            onTap: () => setState(() => _isGridView = false),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? const LinearGradient(
                  colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFFF8008).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.black : _textGrey,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: _isRefreshing ? null : () => _fetchOutlets(forceRefresh: true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: _isRefreshing 
              ? LinearGradient(colors: [_cardBg, _cardBg.withOpacity(0.8)])
              : const LinearGradient(
                  colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: _isRefreshing 
                  ? _primaryGold.withOpacity(0.1)
                  : const Color(0xFFFF8008).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: _isRefreshing ? 1 : 0,
          duration: const Duration(milliseconds: 1000),
          child: Icon(
            Icons.refresh_rounded,
            size: 18,
            color: _isRefreshing ? _textGrey : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8008).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            ).createShader(bounds),
            child: Text(
              'Finding amazing outlets...',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        if (_isRefreshing) _buildRefreshIndicator(),
        Expanded(
          child: _outlets.isEmpty ? _buildEmptyState() : _buildOutletsList(),
        ),
      ],
    );
  }

  Widget _buildRefreshIndicator() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF9B233).withOpacity(0.1),
            const Color(0xFFFF8008).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFFF8008).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8008).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8008)),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Refreshing outlets...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFFF8008),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8008).withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: const Icon(Icons.store_rounded, size: 50, color: Colors.black),
          ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            ).createShader(bounds),
            child: Text(
              'No outlets found',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try refreshing to discover new places',
            style: GoogleFonts.poppins(fontSize: 14, color: _lightGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletsList() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: _isGridView ? _buildGridView() : _buildListView(),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _outlets.length,
      itemBuilder: (context, index) => _buildOutletCard(_outlets[index]),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _outlets.length,
      itemBuilder: (context, index) => _buildOutletListItem(_outlets[index]),
    );
  }

  Widget _buildOutletCard(Outlet outlet) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OutletDetailsScreen(outlet: outlet),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F), Color(0xFF050505)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8008).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedNetworkImage(
                        imageUrl: outlet.image,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildImagePlaceholder(),
                        errorWidget: (context, url, error) => _buildImageError(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8008).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '★ 4.0',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          outlet.name,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFF8008),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Flexible(
                        child: Text(
                          outlet.location,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: _lightGrey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_bronze.withOpacity(0.3), _bronze.withOpacity(0.1)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                outlet.price,
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  color: _bronze,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF8008).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'View',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutletListItem(Outlet outlet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F), Color(0xFF050505)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8008).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: CachedNetworkImage(
              imageUrl: outlet.image,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildImagePlaceholder(size: 80),
              errorWidget: (context, url, error) => _buildImageError(size: 80),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outlet.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFF8008),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  outlet.location,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _lightGrey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_bronze.withOpacity(0.3), _bronze.withOpacity(0.1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        outlet.price,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _bronze,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8008).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '★ 4.0',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder({double? size}) {
    return Container(
      width: size,
      height: size,
      color: _cardBg,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFFF8008)),
        ),
      ),
    );
  }

  Widget _buildImageError({double? size}) {
    return Container(
      width: size,
      height: size,
      color: _cardBg,
      child: Icon(
        Icons.image_not_supported_rounded,
        color: _textGrey,
        size: size != null ? size * 0.4 : 40,
      ),
    );
  }
}