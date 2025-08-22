import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class YourNeighbourhoodScreen extends StatefulWidget {
  final String communityId;
  final String userRole; // 'admin', 'manager', or 'moderator'

  const YourNeighbourhoodScreen({
    Key? key,
    required this.communityId,
    required this.userRole,
  }) : super(key: key);

  @override
  _YourNeighbourhoodScreenState createState() => _YourNeighbourhoodScreenState();
}

class _YourNeighbourhoodScreenState extends State<YourNeighbourhoodScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  bool get canManageOutlets {
    return widget.userRole == 'admin' || 
           widget.userRole == 'manager' || 
           widget.userRole == 'moderator';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A2B1A),
              const Color(0xFF0A1A0A),
              const Color(0xFF0A150A),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildOutletsList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: canManageOutlets ? _buildCreateFAB() : null,
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2B1A).withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1A2B1A), const Color(0xFF0A1A0A)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A2B1A).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.store, 
                  color: Colors.white, 
                  size: isCompact ? 20 : 24
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [const Color(0xFF66BB6A), const Color(0xFF388E3C)],
                      ).createShader(bounds),
                      child: Text(
                        'your neighbourhood',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: isCompact ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'discover local spots',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 10 : 12,
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutletsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('communities')
          .doc(widget.communityId)
          .collection('outlets')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF66BB6A),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            height: 300,
            child: Center(
              child: Text(
                'Error loading outlets',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        final outlets = snapshot.data?.docs ?? [];

        if (outlets.isEmpty) {
          return _buildEmptyState();
        }

        return _buildResponsiveGrid(outlets);
      },
    );
  }

 Widget _buildResponsiveGrid(List<QueryDocumentSnapshot> outlets) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 400;
      final padding = isCompact ? 16.0 : 20.0;
      
      return Padding(
        padding: EdgeInsets.all(padding),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isCompact ? 1 : 2,
            crossAxisSpacing: isCompact ? 8 : 16,
            mainAxisSpacing: isCompact ? 8 : 16,
            // ORIGINAL VALUES:
            // childAspectRatio: isCompact ? 1.1 : 0.9,
            
            // INCREASED HEIGHT - Choose one of these options:
            // Option 1: Moderate increase (recommended)
            childAspectRatio: isCompact ? 0.85 : 0.75,
            
            // Option 2: Significant increase
            // childAspectRatio: isCompact ? 0.7 : 0.6,
            
            // Option 3: Maximum increase (very tall cards)
            // childAspectRatio: isCompact ? 0.6 : 0.5,
          ),
          itemCount: outlets.length,
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            final data = outlet.data() as Map<String, dynamic>;
            
            return OutletCard(
              outletId: outlet.id,
              name: data['name'] ?? '',
              photoUrl: data['photoUrl'] ?? '',
              distance: data['distance'] ?? '',
              travelMode: data['travelMode'] ?? '',
              contactNumber: data['contactNumber'] ?? '',
              canManage: canManageOutlets,
              onEdit: () => _showOutletDialog(context, outlet.id, data),
              onDelete: () => _deleteOutlet(outlet.id, data['photoUrl']),
              onViewImage: () => _showFullImage(data['photoUrl']),
            );
          },
        ),
      );
    },
  );

  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          height: 400,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 16 : 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2B1A).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_outlined,
                    color: const Color(0xFF66BB6A),
                    size: isCompact ? 40 : 48,
                  ),
                ),
                SizedBox(height: isCompact ? 12 : 16),
                Text(
                  'No outlets discovered yet',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isCompact ? 6 : 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 32 : 40),
                  child: Text(
                    canManageOutlets 
                        ? 'Add the first outlet to get started!'
                        : 'Check back later for new spots',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 12 : 14,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF388E3C), const Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF388E3C).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showOutletDialog(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Text(
          'add outlet',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(
          Icons.add,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _showOutletDialog(BuildContext context, [String? outletId, Map<String, dynamic>? existingData]) {
    showDialog(
      context: context,
      builder: (context) => OutletDialog(
        communityId: widget.communityId,
        outletId: outletId,
        existingData: existingData,
        onSaved: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                outletId == null ? 'Outlet added successfully!' : 'Outlet updated successfully!',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF388E3C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
    );
  }

  void _showFullImage(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.white, size: 48),
                          const SizedBox(height: 26),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteOutlet(String outletId, String? photoUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2B1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Outlet',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this outlet? This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade600, Colors.red.shade800],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete photo from storage if exists
        if (photoUrl != null && photoUrl.isNotEmpty) {
          await _storage.refFromURL(photoUrl).delete();
        }

        // Delete outlet document
        await _firestore
            .collection('communities')
            .doc(widget.communityId)
            .collection('outlets')
            .doc(outletId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Outlet deleted successfully!',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF388E3C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting outlet: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

class OutletCard extends StatelessWidget {
  final String outletId;
  final String name;
  final String photoUrl;
  final String distance;
  final String travelMode;
  final String contactNumber;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewImage;

  const OutletCard({
    Key? key,
    required this.outletId,
    required this.name,
    required this.photoUrl,
    required this.distance,
    required this.travelMode,
    required this.contactNumber,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.onViewImage,
  }) : super(key: key);

  IconData _getTravelModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'driving':
        return Icons.directions_car;
      case 'bus':
        return Icons.directions_bus;
      case 'bike':
        return Icons.directions_bike;
      case 'metro':
        return Icons.train;
      case 'local train':
        return Icons.train;
      default:
        return Icons.location_on;
    }
  }

  String _getTravelModeText(String mode) {
    switch (mode.toLowerCase()) {
      case 'walking':
        return 'Walking';
      case 'driving':
        return 'Driving';
      case 'bus':
        return 'Bus';
      case 'bike':
        return 'Bike';
      case 'metro':
        return 'Metro';
      case 'local train':
        return 'Local Train';
      default:
        return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A2B1A).withOpacity(0.3),
                const Color(0xFF0A1A0A).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
            border: Border.all(
              color: const Color(0xFF1A2B1A).withOpacity(0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2B1A).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCompact ? 12 : 16),
            child: Column(
              children: [
                // Photo Section
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: photoUrl.isNotEmpty ? onViewImage : null,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A2B1A).withOpacity(0.3),
                            const Color(0xFF0A1A0A).withOpacity(0.2),
                          ],
                        ),
                      ),
                      child: photoUrl.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPhotoPlaceholder();
                                  },
                                ),
                                // View overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildPhotoPlaceholder(),
                    ),
                  ),
                ),
                
                // Content Section
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isCompact ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Distance and Travel Mode
                        Row(
                          children: [
                            Icon(
                              _getTravelModeIcon(travelMode),
                              size: isCompact ? 14 : 16,
                              color: const Color(0xFF66BB6A),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$distance via ${_getTravelModeText(travelMode)}',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 12 : 13,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        if (contactNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone,
                                size: isCompact ? 14 : 16,
                                color: const Color(0xFF66BB6A),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  contactNumber,
                                  style: GoogleFonts.poppins(
                                    fontSize: isCompact ? 12 : 13,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const Spacer(),
                        
                        // Action Buttons
                        if (canManage)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: onEdit,
                                  icon: const Icon(Icons.edit),
                                  color: const Color(0xFF66BB6A),
                                  iconSize: isCompact ? 16 : 18,
                                  constraints: BoxConstraints(
                                    minWidth: isCompact ? 32 : 36,
                                    minHeight: isCompact ? 32 : 36,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: onDelete,
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red.shade400,
                                  iconSize: isCompact ? 16 : 18,
                                  constraints: BoxConstraints(
                                    minWidth: isCompact ? 32 : 36,
                                    minHeight: isCompact ? 32 : 36,
                                  ),
                                  padding: EdgeInsets.zero,
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
        );
      },
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2B1A).withOpacity(0.3),
            const Color(0xFF0A1A0A).withOpacity(0.2),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.store,
          size: 48,
          color: const Color(0xFF66BB6A).withOpacity(0.7),
        ),
      ),
    );
  }
}

class OutletDialog extends StatefulWidget {
  final String communityId;
  final String? outletId;
  final Map<String, dynamic>? existingData;
  final VoidCallback onSaved;

  const OutletDialog({
    Key? key,
    required this.communityId,
    this.outletId,
    this.existingData,
    required this.onSaved,
  }) : super(key: key);

  @override
  _OutletDialogState createState() => _OutletDialogState();
}

class _OutletDialogState extends State<OutletDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _distanceController = TextEditingController();
  final _contactController = TextEditingController();
  
  String _selectedTravelMode = 'walking';
  File? _selectedImage;
  String? _existingPhotoUrl;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _travelModes = [
    {'value': 'walking', 'label': 'Walking', 'icon': Icons.directions_walk},
    {'value': 'driving', 'label': 'Driving', 'icon': Icons.directions_car},
    {'value': 'bus', 'label': 'Bus', 'icon': Icons.directions_bus},
    {'value': 'bike', 'label': 'Bike', 'icon': Icons.directions_bike},
    {'value': 'metro', 'label': 'Metro', 'icon': Icons.train},
    {'value': 'local train', 'label': 'Local Train', 'icon': Icons.train},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _nameController.text = widget.existingData!['name'] ?? '';
      _distanceController.text = widget.existingData!['distance'] ?? '';
      _contactController.text = widget.existingData!['contactNumber'] ?? '';
      _selectedTravelMode = widget.existingData!['travelMode'] ?? 'walking';
      _existingPhotoUrl = widget.existingData!['photoUrl'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(isCompact ? 16 : 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isCompact ? double.infinity : 600,
              maxHeight: constraints.maxHeight * 0.9,
            ),
            padding: EdgeInsets.all(isCompact ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A2B1A),
                  const Color(0xFF0A1A0A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1A2B1A).withOpacity(0.4),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.all(isCompact ? 10 : 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF388E3C), const Color(0xFF66BB6A)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF388E3C).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.store,
                            color: Colors.white,
                            size: isCompact ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.outletId == null ? 'add new outlet' : 'edit outlet',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: isCompact ? 18 : 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Photo Section
                    Text(
                      'Photo',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_selectedImage != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty))
                                ? const Color(0xFF66BB6A)
                                : Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : _existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _existingPhotoUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        size: 48,
                                        color: const Color(0xFF66BB6A),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to add photo',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Form Fields
                    _buildTextField(
                      controller: _nameController,
                      label: 'Outlet Name',
                      icon: Icons.store,
                      isCompact: isCompact,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Outlet name is required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _distanceController,
                      label: 'Distance from College',
                      icon: Icons.location_on,
                      hint: 'e.g., 2.5 km, 10 mins',
                      isCompact: isCompact,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Distance is required';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _contactController,
                      label: 'Contact Number',
                      icon: Icons.phone,
                      hint: 'e.g., +91 98765 43210',
                      keyboardType: TextInputType.phone,
                      isCompact: isCompact,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Contact number is required';
                        }
                        if (value.trim().length < 10) {
                          return 'Please enter a valid contact number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Travel Mode Dropdown
                    Text(
                      'Best Travel Mode',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedTravelMode,
                        dropdownColor: const Color(0xFF1A2B1A),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.directions,
                            color: const Color(0xFF66BB6A),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _travelModes.map((mode) {
                          return DropdownMenuItem<String>(
                            value: mode['value'],
                            child: Row(
                              children: [
                                Icon(
                                  mode['icon'],
                                  size: 20,
                                  color: const Color(0xFF66BB6A),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  mode['label'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTravelMode = value!;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF66BB6A).withOpacity(0.5),
                              ),
                            ),
                            child: TextButton(
                              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF66BB6A),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFF388E3C), const Color(0xFF66BB6A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF388E3C).withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: _isLoading ? null : _saveOutlet,
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      widget.outletId == null ? 'Add Outlet' : 'Update Outlet',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isCompact,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF66BB6A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF66BB6A),
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Future<void> _saveOutlet() async {
    // Check if photo is provided for new outlets
    if (widget.outletId == null && _selectedImage == null && (_existingPhotoUrl == null || _existingPhotoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add a photo for the outlet',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? photoUrl = _existingPhotoUrl;
      
      // Upload new image if selected
      if (_selectedImage != null) {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = FirebaseStorage.instance
            .ref()
            .child('communities')
            .child(widget.communityId)
            .child('outlets')
            .child(fileName);

        final UploadTask uploadTask = ref.putFile(_selectedImage!);
        final TaskSnapshot snapshot = await uploadTask;
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      final outletData = {
        'name': _nameController.text.trim(),
        'distance': _distanceController.text.trim(),
        'contactNumber': _contactController.text.trim(),
        'travelMode': _selectedTravelMode,
        'photoUrl': photoUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.outletId == null) {
        // Creating new outlet
        outletData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('outlets')
            .add(outletData);
      } else {
        // Updating existing outlet
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('outlets')
            .doc(widget.outletId)
            .update(outletData);
      }

      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving outlet: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}